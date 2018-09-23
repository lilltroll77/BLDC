/*
 * spi.xc
 *
 *  Created on: 23 sep 2018
 *      Author: Mikael Bohman
 */

#include <xs1.h>
#include <xclib.h>
#include <print.h>
#include "typedefs.h"

extern void wait(unsigned clk);

void WriteToDRV8320S(unsigned addr , unsigned data , SPI_t &spi_r){
    spi_r.CTRL <: 0b01; //enable !nSCS
    wait(40);
    spi_r.CLK <: 0x55555555;
    unsigned word=bitrev((addr&0xF)<<27 | (data&0x7FF)<<16);
    spi_r.MOSI<:(zip(word , word , 0));
    start_clock(spi_r.clkblk);
    partout(spi_r.MOSI ,1 ,0);
    sync(spi_r.MOSI);
    stop_clock(spi_r.clkblk);
    wait(40);
    spi_r.CTRL <: 0b11; //enable nSCS
    wait(4000);
}

unsigned ReadFromDRV8320S(unsigned addr , SPI_t &spi_r){
    spi_r.CTRL <: 0b01; //enable !nSCS
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
    spi_r.CTRL <: 0b11; //enable nSCS
    unsigned long long miso;
    spi_r.MISO :> miso;
    wait(4000);
    unsigned data1 , data2;

    {data1 , data2}= unzip( miso,0);
    //return data2;
    return bitrev(data1<<16)& 0x7FF;
}

void init_TIdriver( SPI_t &spi_r){
    spi_r.CTRL <: 0;
    wait(1000); //reset
    spi_r.CTRL <: 3;
    wait(100000); // wait for ADC to stab
    //WriteToDRV8320S( 0x2 , 0b0100000 , spi_r); // Driver control PWM3
    //WriteToDRV8320S( 0x3 , 0x300 , spi_r); // OCP PWM3
    unsigned reg[] = {0 , 0 , 0 , 0x312, 0x712 , 0x19};

    for(int addr=3 ; addr<=5 ; addr++){
        int data=reg[addr];
        WriteToDRV8320S( addr , data , spi_r); // OCP PWM3
        int readback = ReadFromDRV8320S(addr , spi_r);
        if(readback != data)
            printstrln("Error in SPI com. to TI gatedriver");
    }
}

void supervisor(in port p_button , in port p_fault , SPI_t &spi_r){
    set_core_high_priority_off();
    int button;
    p_button :> button;
    while(1){
        select{
        case p_button when pinsneq(button):>button:
            if((button&1)==0 ){
                spi_r.CTRL <: 0;
                printstr("SHUTDOWN");
                return;
            }
            break;
        case p_fault when pinseq(0):>void:

            printstrln("DRV ERROR");
            for(int addr=0 ; addr<=5 ; addr++){
                int miso = ReadFromDRV8320S(addr , spi_r);
                printint(addr);
                printstr(": ");
                printhexln(miso);
            }
            spi_r.CTRL <: 0;
            return;
            break;
        }
    }
}
