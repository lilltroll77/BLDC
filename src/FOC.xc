/*
 * FOC.xc
 *
 *  Created on: 23 sep 2018
 *      Author: Mikael Bohman
 */

#include "svm.h"
#include "xs1.h"
#include "typedefs.h"
#include <xscope.h>
#include "stdio.h"
#include "stdlib.h"
#include "string.h"
#include "typedefs.h"
#include "gui_server.h"
#include "cdc_handlers.h"
#include "FOC.h"

#define DEBUG 0

static inline
void writeCPUloadNow(int x , struct hispeed_t* unsafe mem){
    //struct hispeed_t* offset=0;
    //const unsigned* pos = &offset->CPUload;
    asm("stw %0 , %1[%2]" :: "r"(x), "r"(mem) , "r"(7));
}

unsafe void FOC(streaming chanend c_I[2] , streaming chanend c_fi , streaming chanend c_out , streaming chanend c_gui_server , streaming chanend c_from_CDC){
    struct sharedMem_t shared_mem;
    struct hispeed_t* unsafe mem;
    struct fuse_t* unsafe fuse = &shared_mem.fuse;
    struct state_t state[4];
    struct data64_t Int[2];
    struct regulator_t reg[2];
    memset( &shared_mem , 0 , sizeof(shared_mem));
    memset( state , 0 , sizeof(state));
    memset( Int   , 0 , sizeof(Int));
    memset( reg , 0 , sizeof(reg));
    for(int i=0; i<2 ; i++){
        for(int j=0; j<2 ; j++)
            reg[i].EQ[j].shift = -1; //Disable all filters

    }

    c_from_CDC <:(int* unsafe) reg;
    c_from_CDC <:(int* unsafe) state;

    c_gui_server <: fuse;
    c_out :> int _; //Syncronise
    c_out <:(struct hispeed_t* unsafe) &shared_mem.dsp[0].fast;
    c_out <:(struct hispeed_t* unsafe) &shared_mem.dsp[1].fast;

    timer tmr1;
    unsigned t[2];
    int block=0;
    int ctrl=0;
    tmr1 :> t[0];
    tmr1 :> t[1];
    while(1){
        select{
        default:
            c_fi <: 0;
            mem = &shared_mem.dsp[block].fast;
            block = !block;
             //c_out <: mem;
            tmr1 :> t[0];
            writeCPUloadNow(t[0] - t[1] ,mem);
            c_I[0]:> mem->IA;
            c_I[1]:> mem->IC;
            tmr1 :> t[1];


            int cos_fi , sin_fi;
            c_fi:> sin_fi;
            c_fi:> cos_fi;

            /* DSP END */
            if(ctrl)
                c_gui_server <: mem;
       break;
        case c_from_CDC :> int cmd:
            //printf("FOC cmd: %d\n" , cmd);
            switch(cmd){
            case streamOUT:
                c_from_CDC :> ctrl;
#if(DEBUG==1)
                printf("Stream %d\n" , ctrl);
#endif
                break;
            case PIsection:
                struct regulator_t* unsafe reg_ptr;
                c_from_CDC :> reg_ptr;
                c_from_CDC :> reg_ptr->P;
                c_from_CDC :> reg_ptr->I;
#if(DEBUG==1)
                printf("P=%d I=%d\n" , reg_ptr->P , reg_ptr->I);
#endif
                break;
            case EQsection:
                struct EQ_t* unsafe eq;
                c_from_CDC :> eq;
                //printf("EQ %d\n" , ptr);
                c_from_CDC :> eq->B0;
                c_from_CDC :> eq->B1;
                c_from_CDC :> eq->B2;
                c_from_CDC :> eq->A1;
                c_from_CDC :> eq->A2;
                c_from_CDC :> eq->shift;
                // Verified that above compiles to imediate stw instructions
#if(DEBUG==1)
                printf("B0=%d, B1=%d, B2=%d, A1=%d, A2=%d Shift=%d\n" ,
                        eq->B0 , eq->B1, eq->B2, eq->A1, eq->A2 , eq->shift);
#endif

                break;
            case resetPI:
                int ch;
                c_from_CDC :> ch;
                (Int[ch] , long long )=0; //reset first 64 bits
#if(DEBUG==1)
                printf("Reset ch:%d\n", ch);
#endif
                break;
            case resetEQsec:
                s64* unsafe ptr;
                c_from_CDC :> ptr;
                ptr[0]=0; //y1
                ptr[1]=0; //y2
                ptr[2]=0; //x1,x2
                ((int*)ptr)[6]=0; //error
                break;
            case FuseCurrent:
                c_from_CDC :> shared_mem.fuse.current;
#if(DEBUG==1)
                printintln(shared_mem.fuse.current);
#endif
                break;
            case FuseStatus:
                c_from_CDC :>  shared_mem.fuse.state;
#if(DEBUG==1)
                printstr("Fuse:");
                printintln(shared_mem.fuse.state);
#endif
                break;
            case SignalSource:
                c_from_CDC :> int signalsource;
                break;
            default:
                printstr("Error in FOC: Unknown command\n");
                break;
            }
            break;
        }




    }
}




