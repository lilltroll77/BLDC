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

#define BUFF_LEN 5

void printDec(short data){
    printint(data/10);
    printchar('.');
    printint(data%10);
}

enum COMMAND{COM_STOP, COM_DRV , COM_NEWTEMP};

[[combinable]] void GUIhandler(client interface usb_cdc_interface cdc , client interface GUI_supervisor_interface supervisor){
    set_core_high_priority_off();
    short data[BUFF_LEN];
    while(1){
        select{
        case supervisor.data_waiting():
            int info = supervisor.getInfo();
            if(info &COM_DRV){ // Send all status reg to GUI
            int i=0;
                for(i=0; i <=2 ; i++){
                data[2+i] = supervisor.readGateDriver(i);
                unsigned len=2+i*2;
                (data , char[])[0]=len;
                (data , char[])[1]=COM_DRV;
                cdc.write((data , char[]) , len);
                }
            }
            if( info &SHUTDOWN ){
                unsigned len=2;
                (data , char[])=len;
                (data , char[])=COM_STOP;
                cdc.write((data , char[]) , len);
            }
            if( info &TEMP_CHANGED ){
                unsigned len=2 + 1;
                data[1]=supervisor.readTemperature();
                (data , char[])=len;
                (data , char[])=COM_STOP;
                cdc.write((data , char[]) , len);
            }
            break;
        case cdc.data_ready():
            unsigned bytes;
            do{
                bytes = cdc.available_bytes();
                if(bytes>=4){
                    unsigned len=4;
                    cdc.read( (data , char[]) , len);
                    int ID = (data , char[])[1];
                    switch(ID){
                    case 0:
                        printstr("Torque=");
                        printDec(data[1]);
                        printcharln('%');
                        break;
                    case 1:
                        printstr("Max current=");
                        printDec(data[1]);
                        printcharln('A');
                        break;
                    case 2:
                        printstr("Flux=");
                        printDec(data[1]);
                        printcharln('%');
                        break;
                    case 3:
                        printstr("PI Torque freq=");
                        printDec(data[1]);
                        printstrln("Hz");
                        break;
                    case 4:
                        printstr("PI Torque gain=");
                        printDec(data[1]);
                        printstrln("dB");
                        break;
                    case 5:
                        printstr("PI Flux freq=");
                        printDec(data[1]);
                        printstrln("Hz");
                        break;
                    case 6:
                        printstr("PI Flux gain=");
                        printDec(data[1]);
                        printstrln("dB");
                        break;
                    default:
                        printstrln("Unknowned");
                        break;
                    }
                }
                else
                    wait(10000);

            }while(bytes>0);
            break;
        }
    }
}
