/*
 * GUIhandler.xc
 *
 *  Created on: 25 sep 2018
 *      Author: micke
 */
#include "xud_cdc.h"
#include "print.h"
#include "xscope.h"
#include "supervisor.h"

extern void wait(unsigned clk);

#define BUFF_LEN 16
#define HISIDE_REG 3
#define LOSIDE_REG 4
#define TDRIVE_REG 4
#define ODT_REG 5
#define VDS_REG 5

void printDec(short data){
    printint(data/10);
    printchar('.');
    printint(data%10);
}

enum COMMAND{LINK_DOWN , LINK_UP , COM_CURRENT , COM_STOP, COM_DRV , COM_DRV_ERROR , COM_NEWTEMP , COM_FUSE , COM_RESET , COM_VDS , COM_ODT , COM_TDRIVE , COM_IDRIVE_P_HS , COM_IDRIVE_N_HS , COM_IDRIVE_P_LS , COM_IDRIVE_N_LS , COM_SET_TORQUE , COM_SET_FLUX , COM_PI_FUSE , COM_PI_TORQUE_FREQ , COM_PI_TORQUE_GAIN , COM_PI_FLUX_FREQ , COM_PI_FLUX_GAIN};

[[combinable]] void GUIhandler(client interface usb_cdc_interface cdc , client interface GUI_supervisor_interface supervisor){
    set_core_high_priority_off();
    short data[BUFF_LEN]={0};
    unsigned t;
    timer tmr;
    tmr:>t;
    char command;
    do{
    select{
        case cdc.data_ready():
            unsigned len=2;
            while(cdc.available_bytes() < len)
                wait(1000);
            cdc.read( (data , char[]) , len);
           break;
        }
    command = (data , char[])[1];
    //printint(command);
    }while( command != LINK_UP);

    //Send DRV settings to host
    {
        unsigned len=2+6*sizeof(short);
        (data , char[])[0]=len;
        (data , char[])[1]=COM_DRV;
        for(int reg=0; reg <=5 ; reg++)
            data[1+reg] = supervisor.readGateDriver(reg);
        cdc.write((data , char[]) , len);

        len=2 + sizeof(short);
        data[1]=supervisor.readTemperature(0);
        (data , char[])[0]=len;
        (data , char[])[1]=COM_NEWTEMP;
        cdc.write((data , char[]) , len);

    }
    printstrln("Link up");
   int measurements=0;
#define mSEC 1e5
    while(1){
        select{
        case tmr when timerafter(t+(25*mSEC)):>void:
                unsigned len=2 + 2*sizeof(short);
                (data , char[])[0]=len;
                (data , char[])[1]=COM_CURRENT;
                unsigned current = supervisor.readCurrent(0);
                (data,unsigned short[])[1]= current>>16;
                (data,unsigned short[])[2]= current&0xFFFF;
                cdc.write((data , char[]) , len);
                tmr:>t;
               /* measurements++;
                printint(measurements);
                printchar(',');
                printintln(current);
*/
                break;
        case supervisor.data_waiting():
            int info = supervisor.getInfo();
            while(info != 0){
                //printstr("INFO: ");
                //printhexln(info);

                if(info &DRV_ERROR){ // Send error status reg to GUI
                        info &=~DRV_ERROR;
                        int i=0;
                        for(i=0; i <2 ; i++){
                            data[2+i] = supervisor.readGateDriver(i);
                            unsigned len=2+i*sizeof(short);
                            (data , char[])[0]=len;
                            (data , char[])[1]=COM_DRV_ERROR;
                            cdc.write((data , char[]) , len);
                        }
                        //printstrln("Written Driver");
                    }
                    if( info &SHUTDOWN ){
                        info &=~SHUTDOWN;
                        unsigned len=2;
                        (data , char[])[0]=len;
                        (data , char[])[1]=COM_STOP;
                        cdc.write((data , char[]) , len);
                        printstrln("Written shutdown");
                    }
                    if( info &TEMP_CHANGED ){
                        info &=~TEMP_CHANGED;
                        unsigned len=2 + sizeof(short);
                        data[1]=supervisor.readTemperature(0);
                        (data , char[])[0]=len;
                        (data , char[])[1]=COM_NEWTEMP;
                        cdc.write((data , char[]) , len);
                        printstrln("Written Temp");
                    }
                    if(info &OVER_CURRENT){
                        info &=~OVER_CURRENT;
                        unsigned len=2 + sizeof(int);
                        (data , char[])[0]=len;
                        (data , char[])[1]=COM_FUSE;
                        unsigned current = supervisor.readCurrent(1);
                        (data,unsigned short[])[1]= current>>16;
                        (data,unsigned short[])[2]= current&0xFFFF;
                        cdc.write((data , char[]) , len);
                    }
            }
            break;
        case cdc.data_ready():
            unsigned bytes=cdc.available_bytes();
            if(bytes>=4){
                bytes=4;
                cdc.read( (data , char[]) , bytes);
                bytes = (data , char[])[0];
                command = (data , char[])[1];
                short data_val = data[1];
                switch(command){
                case LINK_DOWN:
                    printstrln("Link DOWN");
                    break;
                case LINK_UP:
                    printstrln("Link UP");
                    break;
                case COM_VDS:
                    short reg_data=supervisor.readGateDriver(VDS_REG);
                    reg_data &=0xFF0;
                    reg_data |=data_val;
                    supervisor.writeGateDriver(VDS_REG , reg_data);
                    printstr("COM VDS: ");
                    printhex(data_val);printchar(',');printhexln(reg_data);
                    break;
                case COM_ODT:
                    short reg_data=supervisor.readGateDriver(ODT_REG);
                    reg_data &=0x4FF;
                    reg_data |=data_val<<8;
                    supervisor.writeGateDriver(ODT_REG , reg_data);
                    printstr("COM ODT:");
                    printhex(data_val);printchar(',');printhexln(reg_data);
                    break;
                case COM_TDRIVE:
                    short reg_data=supervisor.readGateDriver(TDRIVE_REG);
                    reg_data &=0x4FF;
                    reg_data |=data_val<<8;
                    supervisor.writeGateDriver(TDRIVE_REG , reg_data);
                    printstr("COM TDRIVE:");
                    printhex(data_val);printchar(',');printhexln(reg_data);
                    break;
                case COM_IDRIVE_P_HS:
                    short reg_data=supervisor.readGateDriver(HISIDE_REG);
                    reg_data &=0xF0F;
                    reg_data |=data_val<<4;
                    supervisor.writeGateDriver(HISIDE_REG , reg_data);
                    printstr("COM IDRIVE: P-HS ");
                    printhex(data_val);printchar(',');printhexln(reg_data);;
                    break;
                case COM_IDRIVE_N_HS:
                    short reg_data=supervisor.readGateDriver(HISIDE_REG);
                    reg_data &=0xFF0;
                    reg_data |=data_val;
                    supervisor.writeGateDriver(HISIDE_REG , reg_data);
                    printstr("COM IDRIVE: N-HS ");
                    printhex(data_val);printchar(',');printhexln(reg_data);
                    break;
                   break;
                case COM_IDRIVE_P_LS:
                    short reg_data=supervisor.readGateDriver(LOSIDE_REG);
                    reg_data &=0xF0F;
                    reg_data |=data_val<<4;
                    supervisor.writeGateDriver(LOSIDE_REG, reg_data);
                    printstr("COM IDRIVE: P-LS ");
                    printhex(data_val);printchar(',');printhexln(reg_data);
                    break;
                case COM_IDRIVE_N_LS:
                    short reg_data=supervisor.readGateDriver(LOSIDE_REG);
                    reg_data &=0xFF0;
                    reg_data |=data_val;
                    supervisor.writeGateDriver(LOSIDE_REG , reg_data);
                    printstr("COM IDRIVE: N-LS ");
                    printhex(data_val);printchar(',');printhexln(reg_data);
                    break;
                    break;
                case COM_SET_TORQUE:
                    printstr("Torque Setpoint=");
                    printDec(data_val);
                    printcharln('%');
                    break;
                case COM_SET_FLUX:
                    printstr("Flux Setpoint=");
                    printDec(data_val);
                    printcharln('%');
                    break;
                case COM_FUSE:
                    printstr("FUSE:Max current=");
                    printDec(data_val);
                    unsigned Imax = data_val*((64*64*32)/10);
                    printcharln('A');
                    break;
                case COM_RESET:
                    printstrln("RESET PRESSED");
                    break;
                case COM_PI_TORQUE_FREQ:
                    printstr("PI Torque freq=");
                    printDec(data_val);
                    printstrln("Hz");
                    break;
                case COM_PI_TORQUE_GAIN:
                    printstr("PI Torque gain=");
                    printDec(data_val);
                    printstrln("dB");
                    break;
                case COM_PI_FLUX_FREQ:
                    printstr("PI Flux freq=");
                    printDec(data_val);
                    printstrln("Hz");
                    break;
                case COM_PI_FLUX_GAIN:
                    printstr("PI Flux gain=");
                    printDec(data_val);
                    printstrln("dB");
                    break;
                default:
                    printstr("Unknown: ID=");
                    printintln(command);
                    break;
                }
            }

            break;
        }
    }//while
}
