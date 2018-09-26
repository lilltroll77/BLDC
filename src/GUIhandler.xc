/*
 * GUIhandler.xc
 *
 *  Created on: 25 sep 2018
 *      Author: micke
 */
#include "xud_cdc.h"
#include "print.h"
#include "xscope.h"

extern void wait(unsigned clk);

#define BUFF_LEN 5

void printDec(short data){
    printint(data/10);
    printchar('.');
    printint(data%10);
}

[[combinable]] void GUIhandler(client interface usb_cdc_interface cdc , client interface GUI_supervisor_interface supervisor){
    set_core_high_priority_off();
    short data[BUFF_LEN];
    while(1){
        select{
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
