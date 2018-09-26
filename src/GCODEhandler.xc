/*
 * GCODEhandler.xc
 *
 *  Created on: 25 sep 2018
 *      Author: micke
 */

#include "xud_cdc.h"

[[combinable]] void GCODEhandler(client interface usb_cdc_interface cdc){
    set_core_high_priority_off();
    char data[64];
    while(1){
        select{
        case cdc.data_ready():
            unsigned bytes;
            do{
            bytes = cdc.available_bytes();
            if(bytes>64)
                bytes=64;
            cdc.read( (data , char[]) , bytes);
            }while(bytes>0);
            break;
        }
    }
}
