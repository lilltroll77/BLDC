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
#include "RX_block.h"

#define DEBUG 0



unsafe void gui_server(streaming chanend c_from_RX , streaming chanend c_from_dsp){
    set_core_high_priority_off();
    struct sharedMem_t* unsafe shared_mem;
    unsigned CPUload=0;
    struct hispeed_t* unsafe fast;
    #pragma unsafe arrays

    c_from_dsp :> shared_mem;
    int fuse_current= 32<<14; //32 [A] default
    char fuse_state=1;

    timer tmr;
    unsigned time;
    tmr:>time;
    unsigned sample=0;
    soutct(c_from_RX , CT_VERIFY); //Verification of correct channel connection

    while(1){
        int fuse_data;
        select{
            case c_from_RX :> fuse_data:
                if(fuse_data == fuse_REPLACE){
                    fuse_state = fuse_GOOD;
                    soutct(c_from_dsp , fuse_state);
                }
                else{
                    fuse_current = fuse_data;
                    //printintln(fuse_current);
                }

            break;
        case tmr when timerafter(time + 1e7) :> time:
            //printint(CPUload);
              if(CPUload>0)
                CPUload--;
        break;
        case c_from_dsp :> fast:
            int absIA = abs(fast->IA);
            int absIB = abs(fast->IA + fast->IC);
            int absIC = abs(fast->IC);
            if(absIA < absIB)
                absIA = absIB;
            if(absIA < absIC)
                absIA = absIC;
            unsigned newLoad = shared_mem->CPUload & 2047;
            if( newLoad > CPUload)
                    CPUload = newLoad;
         // send to other tile
/*1*/   c_from_RX <: sample; sample = (sample+1)& (FFT_LEN-1);
/*2*/   c_from_RX <: fast->IA;
        c_from_RX <: fast->IC;
/*4*/   c_from_RX <: fast->Torque;
        c_from_RX <: fast->Flux;
/*6*/   c_from_RX <: fast->U;
        c_from_RX <: fast->angle;
/*8*/   c_from_RX <: CPUload;
        if((absIA > fuse_current) && (fuse_state!=fuse_BLOWNED)){
            // Fuse blown
            fuse_state=fuse_BLOWNED;
            //Signal DSP & RX
            soutct(c_from_RX ,  fuse_BLOWNED);
            soutct(c_from_dsp , fuse_BLOWNED);

        }
        else
            soutct(c_from_RX , fuse_NOCHANGE);
       break;

        }
    }
}



static inline
void writeCPUloadNow(unsigned &t_old , timer tmr , unsigned* mem){
    //struct hispeed_t* offset=0;
    //const unsigned* pos = &offset->CPUload;
    unsigned t_new;
    tmr :> t_new;
    asm("stw %0 , %1[%2]" :: "r"(t_new-t_old), "r"(mem) , "r"(0));
    tmr :> t_old;
}

static inline
int PI(int x, int p , int i , int &hi , unsigned &lo){
    //antiwindup ??
    int h; unsigned l;
    {h , l}  = macs( x , p , 0 , 0 );
    asm("lextract %0,%1,%2,%3,32": "=r"(h):"r"(h),"r"(l) ,"r"(22));

    {hi , lo} = macs( h , i , hi , lo);
    //asm("ladd %0,%1,%2,%3,%4" : "=r"(h), "=r"(l) :  "r"(hi), "r"(lo) , "r"(0));
    return h+hi;
}


unsafe void FOC(streaming chanend c_I[2] , streaming chanend c_fi , streaming chanend c_out , streaming chanend c_gui_server , streaming chanend c_from_CDC){
    struct sharedMem_t shared_mem;
    struct hispeed_t* unsafe mem = &shared_mem.dsp[0].fast;
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

    c_out <:(struct hispeed_t* unsafe) &shared_mem.dsp[0].fast;
    c_out <:(struct hispeed_t* unsafe) &shared_mem.dsp[1].fast;

    timer tmr1;
    unsigned told;
    int block=0;
    int ctrl=0;
    //printint(t[1]-t[0]);

#if(CALIBRATE_QE)
    int fi=-1 , angle;
    //Find trigger
    while(fi<0){
        tmr1 when timerafter(t[0] + 2e4):> t[0];
        c_out<: 1;
        soutct( c_fi , CT );
        c_fi :> fi;
        c_out:> angle;
    }
    for(int i=0; i<2048 ;i++){
        tmr1 when timerafter(t[0] + 1e4):> t[0];
        c_out<: 1;
        c_out:> angle;
    }
    soutct( c_fi , CT );
    c_fi :> fi;
    if(fi>4096)
        printf("Motor spins in wrong direction\n");
    else{

    while(1){
        int mean=0;
        for(int i=0; i<(1<<14) ; i++){
            tmr1 when timerafter(t[0] + 1e4):> t[0];
            soutct( c_fi , CT );
            if(angle > (3*SIN_TBL_LEN))
                c_out<: 1;
            else if(angle > 0)
                c_out<: -1;
            else
                c_out<: 0;
            c_fi :> fi;
            mean += fi;
            c_out :> angle;
        }
        printf("QE Offset = %d\n" , mean>>14);

    }

    }
}

 #else
    unsigned counter=1;
    int fi;
    int Vout = 0x2000;
    int FOCangle=0;

    const int iMax_init=3*AMPERE;
    if(iMax_init > 25*(1<<15)){
        printf("Incorrect current settings\n Limit will clip in ADC\nABORTING!\n");
        while(1);
    }

    soutct(c_I[0] , 0); //start adc
    soutct(c_I[1] , 0); //start adc



timer tmr;
unsigned t;
tmr :> t;
// Charge ADC rail and wait for ADC stabilization
int samples=3e4;
const int Ierror = 1e3; //Maximum error allowed after stab.
do{
        char ct;
        int iA=0x80000000 , iC=0x80000000;
        select{
        case sinct_byref(c_out , ct):
            c_out <: 0;
            c_out <: 0;
            if((iA < Ierror) & (iC < Ierror))
                samples--;
        break;
        case c_I[0]:> iA:
            iA = abs(iA);
        break;
        case c_I[1]:> iC:
            iC = abs(iC);
        break;
        case tmr when timerafter(t + 5e8):>t:
            printf("ADC did not stabalize within 5s!\niA=%d , iC=%d \n !! ABORTING!!", iA , iC);
            while(1);
        break;
        }
    }while(samples!=0);
    printstrln("ADC OK");
    c_out <: 0;
    c_out <: 0;

    //Force motor to FOCangle=0 position with a DC current



    int cont=1;
    do{
        int i;
        char ct;
        select{
        case sinct_byref(c_out , ct):
            samples++;
            c_out <: FOCangle;
            c_out <: Vout;
             if((samples&0x7)==0){
                Vout++;
                if(Vout==0x7FFF) // Increase voltage until Vmax
                    cont=0;
            }
        break;
        case c_fi:> fi:
        break;
        case c_I[0]:> i:
            i = abs(i);
            if((i > iMax_init)){ // Increase voltage until current = Imax
                cont=0;
                //printint(i);
            }
        break;
        case c_I[1]:> i:
            i = abs(i);
            if((i > iMax_init)){ // Increase voltage until current = Imax
                cont=0;
                //printint(i);
            }
        break;
        }
    }while(cont);
    //reset QE until real calib is done based on QE trigger
    c_fi <:0;
    c_fi :> fi;
    //Vout = 0x1000;
    printstrln("OK");


    tmr :> t;

    char ct_fuse=fuse_GOOD;
    char ct;
        while(1){
        select{
            case tmr when timerafter(t + 3e8) :> t:
                    if(ct_fuse != fuse_GOOD)
                        break;
                    if(FOCangle < (3*1024)/2 ) //Rotate vector 90 deg step by step
                        FOCangle++;
                    else if(Vout<0x7FFF) //Then increase voltage
                        Vout++;
            break;
            case sinct_byref(c_gui_server , ct_fuse):
                if(ct_fuse == fuse_BLOWNED){
                    Vout=0;
                    FOCangle=0;
                    printchar('B');
                }
                else
                    printchar('G');


            break;
            case sinct_byref(c_out , ct): // new calc requested
            //writeCPUloadNow( told , tmr1,  &shared_mem.CPUload);
            c_out <: fi + FOCangle;
            c_out <: Vout;

            //c_out <: mem;
            //Scale from QE angle to Space vector angle

            //(B – C)*(1/sqrt(3) = -(A+C)-C /sqrt(3) = (-2*A - 4C)*0.288675134594813
 /*           int Beta;
            unsigned _lo;
            {Beta , _lo} = macs(-2*mem->IA - 4*mem->IC, 1239850262 , 0 , 0x80000000);
            int cos_fi , sin_fi;
            c_fi:> sin_fi;
            c_fi:> cos_fi;

            int Id , Iq;
            unsigned Id_lo , Iq_lo;

            {Id , Id_lo} = macs(mem->IA , cos_fi , 0 , 0x80000000);
            {Id , Id_lo} = macs(Beta    , sin_fi , Id , Id_lo);

            Id = PI( 5000 - Id , reg[0].P , reg[0].I , Int[0].hi , Int[0].lo);


            {Iq , Iq_lo} = macs(Beta    , cos_fi , 0 , 0x80000000);
            {Iq , Iq_lo} = macs(mem->IA ,-sin_fi , Iq , Iq_lo);

            Iq = PI( - Iq , reg[1].P , reg[1].I , Int[1].hi , Int[1].lo);

            int alfa;
            unsigned alfa_lo;
            {alfa , alfa_lo} = macs(Id ,  cos_fi , 0 , 0x80000000);
            {alfa , alfa_lo} = macs(Iq , -sin_fi  ,  alfa , alfa_lo);
            //sqrt(alfa);
*/
            /* DSP END */
            //writeCPUloadNow( told , tmr1,  &shared_mem.CPUload);

        break;
        case c_fi:> fi:
            break;
/* I should be in sync with U !*/
        case c_I[0]:> mem->IA:
             c_I[1]:> mem->IC;
             if(ctrl)
               c_gui_server <: mem;
            counter = !counter;
            if(counter)
                mem = &shared_mem.dsp[1].fast;
            else
                mem = &shared_mem.dsp[0].fast;
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


#endif






