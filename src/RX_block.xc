/*
 * RX_block.xc
 *
 *  Created on: 10 dec 2018
 *      Author: micke
 */
#include "xs1.h"
#include "RX_block.h"
#include "stdio.h"
#include "supervisor.h"

#pragma unsafe arrays
unsafe void RX_block(streaming chanend c_from_gui , streaming chanend c_from_CDC , struct QE_t* unsafe QEptr){
    //Readble version without pointer maniac
    //printf("struct USBmem_t = %d bytes\n" , sizeof(struct USBmem_t));
    set_core_high_priority_off();;
    unsigned long long pi = 3141592543358979324ull;
    //printullongln(pi);
    unsigned sample;
    int block=0;
    struct USBmem_t USBmem[2]={0};
    USBmem[0].checknumber = pi;
    USBmem[1].checknumber = pi;
    USBmem[0].version = CODEVERSION;
    USBmem[1].version = CODEVERSION;
    USBmem[1].changed = (unsigned)-1;
    //printf("RX:i=%d mid=%d fast=%d\n" , i , mid , fast );
    char ct;
    c_from_CDC <: (struct USBmem_t* unsafe) &USBmem[0];
    struct hispeed_vector_t* unsafe fast = &USBmem[block].fast;
    schkct(c_from_gui , CT_VERIFY);//Verification of channel mapping
    while(1){
        select{
        case sinct_byref(c_from_CDC , ct):
            switch(ct){
            case 0:
                block=0;
                fast = &USBmem[block].fast;
                break;
            case fuse_GOOD:
                USBmem[0].changed ^= FUSE_CHANGED;
                USBmem[0].changed |= FUSE_STATE; //set bit to one
                c_from_gui <:fuse_REPLACE;
                //printf("%x\n" , USBmem[0].changed);
                break;
            case fuse_SETCURRENT:
                int i;
                c_from_CDC :> i;
                c_from_gui <:i;
                break;
            default:
                printf("ERROR\n");
                break;
            }

        break;
/*1*/   case c_from_gui :> sample:
            int i=(sample&127);
            fast->QE[i] = QEptr->angle;
/*2*/       c_from_gui :> fast->IA[i];
            c_from_gui :> fast->IC[i];
/*4*/       c_from_gui :> fast->Torque[i];
            c_from_gui :> fast->Flux[i];
/*6*/       c_from_gui :> fast->U[i];
            c_from_gui :> fast->angle[i];
            unsigned load;
/*8*/       c_from_gui :> load;
            if(USBmem[block].DSPload!=load){
                USBmem[block].DSPload = load;
                USBmem[0].changed ^= LOAD_CHANGED;
            }

//Will gererate ET_ILLEGAL_RESOURCE exeption if TX and RX is out of sync with control token
           char token = sinct(c_from_gui);
            if( token == fuse_BLOWNED){
               //Fuse blown
               USBmem[0].changed ^= FUSE_CHANGED;
               USBmem[0].changed &= ~FUSE_STATE; //set bit to zero
              // printf("%x\n" , USBmem[0].changed);

           }
           if(i == 127){
                USBmem[block].index = sample>>7; // 128 samples in each block
                USBmem[block].w = QEptr->dt;
               //printintln(fftTrig>>7);
                c_from_CDC <:(int* unsafe) &USBmem[block]; // send pointer to CDC core
                block = !block;
                fast = &USBmem[block].fast;
                //printf("%d, ", fast->angle[127]);
                break;

            }
            break;
        }
    }
}
