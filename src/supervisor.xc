/*
 * spi.xc
 *
 *  Created on: 23 sep 2018
 *      Author: Mikael Bohman
 */

#include <xs1.h>
#include <xclib.h>
#include <print.h>
#include <stdio.h>
#include "typedefs.h"
#include "one_wire.h"
#include "supervisor.h"

extern void wait(unsigned clk);
//Default values after hard reset
const unsigned init_reg[] = {0 , 0 , 0 , 0x311, 0x611 , 0x19};

void WriteToDRV8320S(unsigned addr , unsigned data , SPI_t &spi_r , int ctrl){
    spi_r.CTRL <: ctrl&1; //enable !nSCS
    wait(40);
    spi_r.CLK <: 0x55555555;
    unsigned word=bitrev((addr&0xF)<<27 | (data&0x7FF)<<16);
    spi_r.MOSI<:(zip(word , word , 0));
    start_clock(spi_r.clkblk);
    partout(spi_r.MOSI ,1 ,0);
    sync(spi_r.MOSI);
    stop_clock(spi_r.clkblk);
    wait(40);
    spi_r.CTRL <: ctrl; //enable nSCS
    wait(4000);
}

unsigned ReadFromDRV8320S(unsigned addr , SPI_t &spi_r , int ctrl){
    spi_r.CTRL <: ctrl&1; //enable !nSCS
    wait(40);
    spi_r.CLK <: 0x55555555;
    unsigned word=bitrev((addr&0xF)<<27)|1;

    spi_r.MOSI<: (zip(word , word , 0));
    clearbuf(spi_r.MISO);
    start_clock(spi_r.clkblk);
    partout(spi_r.MOSI ,1 ,0);
    sync(spi_r.MOSI);
    stop_clock(spi_r.clkblk);
    wait(40);
    spi_r.CTRL <: ctrl; //enable nSCS
    unsigned long long miso;
    spi_r.MISO :> miso;
    wait(4000);
    unsigned data1 , data2;

    {data1 , data2}= unzip( miso,0);
    //return data2;
    return bitrev(data1<<16)& 0x7FF;
}

int init_TIdriver( SPI_t &spi_r){
    spi_r.CTRL <: 0;
    wait(1000); //reset
    int ctrl=3;
    spi_r.CTRL <: ctrl;
    wait(100000); // wait for ADC to stab

    for(int addr=0; addr<=5 ; addr++){
        int data=init_reg[addr];
        WriteToDRV8320S( addr , data , spi_r , ctrl); // OCP PWM3
        int readback = ReadFromDRV8320S(addr , spi_r , ctrl);
        if(readback != data)
            printstrln("Error in SPI com. to TI gatedriver");
#if(DEBUG)
        else
            printintln(readback);
#endif
    }
    return ctrl;
}


//DS18S20 commands
#define MATCH_ROM      0x55
#define READ_ROM       0x33
#define SKIP_ROM       0xCC
#define CONVERT_T      0x44
#define READ_SCRATCH   0xBE
#define WRITE_SCRATCH  0x4E
#define COPY_TO_EEPROM 0x48
#define RECALL_EEPROM  0xB8
#define READ_PSU       0xB4


void write_to_eeprom(client one_wire_if i_one_wire, unsigned char data[2]){
  i_one_wire.check_status();
  i_one_wire.reset();
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(SKIP_ROM);
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(WRITE_SCRATCH);
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(data[0]);
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(data[1]);
  wait_for_completion(i_one_wire);
  i_one_wire.reset();
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(SKIP_ROM);
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(COPY_TO_EEPROM);
  wait_for_completion(i_one_wire);
}

void read_from_eeprom(client one_wire_if i_one_wire, unsigned char data[2]){
  i_one_wire.check_status();
  i_one_wire.reset();
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(SKIP_ROM);
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(RECALL_EEPROM);
  wait_for_completion(i_one_wire);
  i_one_wire.reset();
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(SKIP_ROM);
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(READ_SCRATCH);
  wait_for_completion(i_one_wire);
  unsigned char bytes[9];
  i_one_wire.start_read_bytes(9);
  wait_for_completion(i_one_wire);
  i_one_wire.get_read_bytes(bytes, 9);
  data[0] = bytes[2];
  data[1] = bytes[3];
}

short convert_and_read_scratch(client one_wire_if i_one_wire, unsigned char data[9]){
  i_one_wire.check_status();
  i_one_wire.reset();
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(SKIP_ROM);
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(CONVERT_T);
  wait_for_completion(i_one_wire);
  i_one_wire.reset();
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(SKIP_ROM);
  wait_for_completion(i_one_wire);
  i_one_wire.send_command(READ_SCRATCH);
  wait_for_completion(i_one_wire);
  i_one_wire.start_read_bytes(9);
  wait_for_completion(i_one_wire);
  i_one_wire.get_read_bytes(data, 9);
  return (data[0] | ((short)data[1] << 8));
}


void supervisor(server interface GUI_supervisor_interface supervisor_data , client interface one_wire_if termometer_data , in port p_button , in port p_fault , SPI_t &spi_r){
    set_core_high_priority_off();

    int button;
    unsigned char data[9] = {0};
    p_button :> button;
    int fault , ctrl=3;
    p_fault :>fault;
    unsigned t;
    timer tmr;
    short temp=0;
    unsigned info= DRV_ERROR | DRV_SETTINGS;
    supervisor_data.notification();
    tmr :> t;

    while(1){
        char ct;
#pragma ordered
        select{
            //highest priority
         case p_button when pinsneq(button):>button:
            if((button&1)==0 ){

                WriteToDRV8320S( 2 , BRAKE , spi_r, ctrl);
/* CODE BELOW SEEMS TO SELFDESTRUCT THE POWER MOSFETS
                //ctrl=2;
                //spi_r.CTRL <:ctrl;
                 *
               **********************************  */
                info |= SHUTDOWN;
                supervisor_data.notification();
                printstrln("STOP!");
            }
            break;
        case p_fault when pinsneq(fault):> fault:
            if(fault || (ctrl==2))
                break;
            info |=DRV_ERROR;
            supervisor_data.notification();
            printstrln("DRV ERROR");
            for(int addr=0 ; addr<=5 ; addr++){
                int miso = ReadFromDRV8320S(addr , spi_r , ctrl);
                printint(addr);
                printstr(": ");
                printhexln(miso);
            }

            break;
        case supervisor_data.getInfo() -> int new_info:
                new_info = info;
                info=0;
                break;
        case supervisor_data.readTemperature(char ID) -> short temperature:
                temperature = temp;
                break;
        case supervisor_data.readGateDriver(char reg) -> short data_reg:
//                info |=!DRV_ERROR;
                data_reg=ReadFromDRV8320S(reg , spi_r, ctrl);
                break;
        case supervisor_data.writeGateDriver(char reg , short val) -> int ack:
                WriteToDRV8320S( reg , val , spi_r, ctrl); // OCP PWM3
                int readback = ReadFromDRV8320S(reg , spi_r, ctrl);
                if(readback != val)
                    printf("Error in SPI data to TI gatedriver. Wrote 0x%x , Read 0x%x" , val , readback);
                ack=1;
                break;
        case supervisor_data.resetGateDriver() -> int ack:
                if(ctrl==2) //Hard reset
                    ctrl = init_TIdriver(spi_r);
                else{  //soft reset
                    spi_r.CTRL <:2;
                    wait(1000);
                    spi_r.CTRL <:3;
                    WriteToDRV8320S( 2 , NORMAL, spi_r, ctrl);
                }

                printstrln("Reset Done");
                info=0;
                info |=DRV_ERROR;
                info |=DRV_SETTINGS;
                ack=1;
                supervisor_data.notification();

                break;
                //lowest priority
        case tmr when timerafter(5e7 + t):>void:
                short new_temp  =  convert_and_read_scratch(termometer_data, data);
                tmr:>t;
                if(new_temp != temp) {
                    temp = new_temp;
                    info |=TEMP_CHANGED;
                    supervisor_data.notification();

                }
                break;
        }//select
    }

}



void supervisor_cores(server interface GUI_supervisor_interface supervisor_data , in port p_button , in port p_fault , SPI_t &spi_r , port p_temp){
    interface one_wire_if termometer_data;
    par{
           one_wire(termometer_data, p_temp);
           supervisor(supervisor_data , termometer_data, p_button ,p_fault , spi_r);
       }
}
