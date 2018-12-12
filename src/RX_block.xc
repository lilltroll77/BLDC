/*
 * RX_block.xc
 *
 *  Created on: 10 dec 2018
 *      Author: micke
 */
#include "xs1.h"
#include "RX_block.h"
#include "stdio.h"

#pragma unsafe arrays
unsafe void RX_block(streaming chanend c_from_gui , streaming chanend c_from_CDC , unsigned* unsafe angle){
    //Readble version without full pointer maniac
    set_core_high_priority_off();;
    unsigned long long pi = 3141592543358979324ull;
    //printullongln(pi);
    unsigned mid , fftTrig;
    int block=0,blockNumber;
    struct USBmem_t USBmem[2]={0};
    USBmem[0].checknumber = pi;
    USBmem[1].checknumber = pi;
    USBmem[0].version = CODEVERSION;
    USBmem[1].version = CODEVERSION;
    //printf("RX:i=%d mid=%d fast=%d\n" , i , mid , fast );
    char ct;
    c_from_CDC <: (struct USBmem_t* unsafe) &USBmem[0];
    struct hispeed_vector_t* unsafe fast;
    c_from_gui <: blockNumber;
    while(1){
        select{
        case sinct_byref(c_from_CDC , ct):
            mid=0;
            blockNumber=0;
            fast = &USBmem[block].fast;
        break;
/*1*/   case c_from_gui :> fftTrig:
            int i=(fftTrig&127);
            fast->QE[i] = (*angle)&8191;
            c_from_gui :> fast->IA[i];
            c_from_gui :> fast->IC[i];
            c_from_gui :> fast->Torque[i];
/*5*/       c_from_gui :> fast->Flux[i];
            c_from_gui :> fast->U[i];
            c_from_gui :> fast->angle[i];

            c_from_gui :> USBmem[block].states;
            c_from_gui :> USBmem[block].DSPload;


/*9*/

            if(i == 127){
                USBmem[block].index = fftTrig>>7; // 128 samples in each block
                //printintln(fftTrig>>7);
                c_from_CDC <:(int* unsafe) &USBmem[block]; // send pointer to CDC core
                i=0;
                block = !block;
                fast = &USBmem[block].fast;
                //printf("%d, ", fast->angle[127]);
                break;

            }
            break;
        }
    }
}
