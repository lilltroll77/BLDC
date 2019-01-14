/*
 * FOC.xc
 *
 *  Created on: 23 sep 2018
 *      Author: Mikael Bohman
 */

#include "svm.h"
#include "xs1.h"
#include "xclib.h"
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
#include "math.h"
#include "myMachine.h"

#define DEBUG 0

extern void wait(unsigned clk);



#define SQRT_BITS 14
#define SQRT_LEN (1<<SQRT_BITS)
#define ARCTAN_BITS 7
#define ARCTAN_LEN (1+(1<<ARCTAN_BITS))

unsigned short sqrt_tb[SQRT_LEN];

// sqrt(A*2^(2n)) = 2^n * sqrt(A)
static inline
unsigned sqrt_fixed(unsigned x){
    if(x==0)
        return 0;
    int zeros = clz(x);
    //Normalize to full scale
    x <<= zeros;
    //extract most SQRT_BITS and map to table
    x >>= (31-SQRT_BITS);
    x -=(SQRT_LEN);
    //Table lookup and shift with zeros/2
    if( x>= SQRT_LEN){
        printstr("SQRT: ");
        printintln(x);
     while(1);
    }
    x=sqrt_tb[x]>>(zeros>>1);
    unsigned _;
    if(zeros&1) // if zeros has an reminder divide by 1/sqrt(2)
        {x,  _}=lmul(x , 3037000500 ,0 ,0x80000000);
    return x;


}

unsafe void gui_server(streaming chanend c_from_RX , streaming chanend c_from_dsp){
    set_core_high_priority_off();
    unsigned CPUload=0;
    struct hispeed_t* unsafe fast;
    #pragma unsafe arrays

    int fuse_current= 33*AMPERE; //32 [A] default
    fuse_current = 0x7FFFFFFF;
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
                    //NOT ACTIVE
                    //fuse_current = fuse_data;
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
            if( fast->DSPload > CPUload)
                    CPUload = fast->DSPload;
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
void writeCPUloadNow(unsigned t_old , timer tmr , unsigned* mem){
    unsigned t_new;
    tmr :> t_new;
    asm("stw %0 , %1[%2]" :: "r"(t_new-t_old), "r"(mem) , "r"(0));
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

#define  ldivu(a,b,c,d,e) asm("ldivu %0,%1,%2,%3,%4" : "=r" (a), "=r" (b): "r" (c), "r" (d), "r" (e))


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
    //Calculate square root table with 16 bit resolution
        for(unsigned i=0; i< SQRT_LEN ; i++){
                double x= 1.0+(double)i /SQRT_LEN; //[1 2]
               sqrt_tb[i] = sqrt(x*pow(2,31)); //[sqrt(2) 2]<<15

           }
    short arctan[ARCTAN_LEN];
    short arccot[ARCTAN_LEN];
    const double a_scale = (QE_RES/8)/MOTOR_MAG*4.0/M_PI;
    for(unsigned i=0; i< ARCTAN_LEN ; i++){
        arctan[i] = a_scale*atan((double)i/ARCTAN_LEN);
        arccot[i] = a_scale*(M_PI_2-atan((double)i/ARCTAN_LEN));
    }


    for(int i=0; i<2 ; i++){
        for(int j=0; j<2 ; j++)
            reg[i].EQ[j].shift = -1; //Disable all filters

    }

    c_from_CDC <:(int* unsafe) reg;
    c_from_CDC <:(int* unsafe) state;

    c_out <:(struct hispeed_t* unsafe) &shared_mem.dsp[0].fast;
    c_out <:(struct hispeed_t* unsafe) &shared_mem.dsp[1].fast;

    int ctrl=0;
    //printint(t[1]-t[0]);

    unsigned counter=1;
    int fi;
    int VoutSet = 0;
    int Vout=0;
    int FOCangle=0;



    int iMax_init=(TEST_mA*AMPERE)/1000;
    if(iMax_init > 24<<15){
        iMax_init = (24<<15);
        printf("! Warning: Testcurrent reduced to %d mA to avoid ADC clipping !\n" , (1000*iMax_init)/AMPERE);

    }

    soutct(c_I[0] , 0); //start adc
    soutct(c_I[1] , 0); //start adc



timer tmr;
unsigned t;

// Charge ADC rail and wait for ADC stabilization
int samples=6e4;
const int Ierror = 500; //Maximum error allowed after stab.
int iA=0x80000000 , iC=0x80000000;
int iAsum=0; int iCsum=0;
int iAmean=2*Ierror , iCmean=2*Ierror;
#define SUM_LEN 4096
int sumA=SUM_LEN;
int sumC=SUM_LEN;
tmr :> t;
do{
        char ct;
        select{
        case c_out :> int _:
            c_out <: 0;
            c_out <: 0;
            if((abs(iAmean) < Ierror) & (abs(iCmean) < Ierror))
                samples--;
        break;
        case c_I[0]:> iA:
        iAsum +=iA;
        if(sumA==0){
            iAmean = iAsum/SUM_LEN;
            sumA=SUM_LEN;
            iAsum=0;
        }
        else
            sumA--;
        break;
        case c_I[1]:> iC:
        iCsum +=iC;
        if(sumC==0){
            iCmean = iCsum/SUM_LEN;
            sumC=SUM_LEN;
            iCsum=0;
        }
        else
            sumC--;
        break;
        case tmr when timerafter(t + 3e8):>t:
            printf("ADC did not stabalize within 3s!\niAoffset=%d , iCoffset=%d after compensation\n !! ABORTING!! ADC offset values in myMachine.h needs to be adjusted\n", iAmean , iCmean);
            while(1);
        break;
        }
    }while(samples!=0);
unsigned tend;
tmr :> tend;
int ms=100*1000;
printf("ADC did stabalize after %d ms with an compensated iAoffset=%d and iCoffset=%d\n!!! ALWAYS PRESS THE STOP SWITCH BEFORE STOPPING PROGRAM EXECUTION !!!\n\n",(tend-t)/ms ,iAmean , iCmean);
#if(!CALIBRATE_QE)
printf("Now waiting for an input command from the GUI!\n\n");
#endif
    //Force motor to FOCangle=0 position with a DC current



    int cont=1;
    do{
        int i;
        char ct;
        select{
        case c_out :> FOCangle:
            samples++;
            c_out <: FOCangle;
            c_out <: VoutSet;
             if((samples&0x7)==0){
                VoutSet++;
                if(VoutSet==0x7FFF) // Increase voltage until Vmax
                    cont=0;
            }
        break;
        case c_fi:> fi:
             c_fi:> int _;
             c_fi:> int _;
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

    wait(5e7);

    fi=0;
    c_fi <:fi; // reset QE angle

//Now rotate the field 90 deg.
    FOCangle = (3*1024/2);

    char ct_fuse=fuse_GOOD;
    samples=0;
#if(CALIBRATE_QE)
    printstrln("Searching for QE trigger");
    int QEmean=0 , trigged=0;
#else
    VoutSet=0;
#endif
    int fuse=1;
    int cos_fi , sin_fi;



        while(1){
        select{
           case sinct_byref(c_gui_server , ct_fuse):
                if(ct_fuse == fuse_BLOWNED){
                    VoutSet=0;
                    Vout=0;
                    fuse=0;
                    //FOCangle=0;
                    printstrln("Blown fuse");
                }
                else{
                    printstrln("New fuse");
                    fuse=1;
                }


            break;
#if(CALIBRATE_QE)
           case c_out:> int fi_FOC: // new calc requested
            //writeCPUloadNow( told , tmr1,  &shared_mem.CPUload);

            if(samples==0){
                if((trigged>0) & (fi_FOC ==0)){
                    int QEpoint = fi%(8192/7);
                    QEmean +=QEpoint;
                    printint(QEpoint);
                    printstr(", mean QE_OFFSET value=");
                    printintln(QEmean/trigged);
                    trigged++;
                }

                samples=100;
                fi_FOC++;

            }
            else
                samples--;
            c_out <: fi_FOC;
            c_out <: VoutSet;
            break;
#else
           case c_out:>int _:
               tmr:>t;
               if(Vout < VoutSet)
                   Vout += dV_LIMIT;
               else if(Vout > VoutSet)
                   Vout -=dV_LIMIT;
               if(Vout<0){
                   c_out <: fi-FOCangle;
                   c_out <: -Vout + PWM_MIN;
               }else if(Vout>0){
                   c_out <: fi+FOCangle;
                   c_out <: Vout + PWM_MIN;
               }
               else{
                   c_out <: fi;
                   c_out <: 0;
               }
                     //Transform input signals to direct quadrature
               unsigned _lo;
               int Beta;
               //BETA = (ib-ic)/sqrt(3);
               int scale = 1239850262;//2*(ib-ic)*(2^31/sqrt(3))
               /* 2*(ib - ic) = 2*(-(ia+ic)-ic) = -2*(ia + 2*ic) */
               int i =-2*(mem->IA + 2*mem->IC);
               {Beta , _lo} = macs(i, scale , 0 , 0x80000000);

               unsigned hi=0 , lo=0x80000000;
               {hi , lo} = macs(mem->IA , cos_fi , hi , lo);
               {hi , lo} = macs(Beta    , sin_fi , hi , lo);
               mem->U = hi*hi;
               mem->Flux = hi;
               //Id = PI( VoutSet - Id , reg[0].P , reg[0].I , Int[0].hi , Int[0].lo);

               lo=0x80000000;
               hi=0;
               {hi , lo} = macs(Beta    , cos_fi , hi , lo);
               {hi , lo} = macs(mem->IA ,-sin_fi , hi , lo);
               mem->U += hi*hi;
               mem->Torque = hi;

               mem->U = sqrt_fixed(mem->U);
               unsigned flux = 1+abs(mem->Flux);
               unsigned torque = 1+abs(mem->Torque);
               if(flux > torque){
                   unsigned q=(torque<<ARCTAN_BITS)/flux;
                   if(q>=ARCTAN_LEN){
                       printint(q);
                       while(1);
                   }
                   mem->angle = arctan[q];
               }else{
                   unsigned q=(flux<<ARCTAN_BITS)/torque;
                   if(q>=ARCTAN_LEN){
                       printint(q);
                       while(1);
                   }
                   mem->angle = arccot[q];
               }
               if(mem->Torque < 0)
                   mem->angle =-mem->angle;

               unsigned t_new;
               tmr :> t_new;
               mem->DSPload = t_new-t;
               break;
                  case c_fi:> fi:
                      c_fi:> sin_fi;
                      c_fi:> cos_fi;
                 break;
#endif
#if(CALIBRATE_QE)
            case c_fi:> fi:
            if(!trigged & (fi==0)){
               printstrln("QE trigger found. Testing magnetic sectors");
               printstrln("Motor must run freely!");
               printstrln("WARNING: Motor coils might get hot! Manual supervision needed");
               printstrln("Press the stop switch to stop the motor test currents");
               printstrln("Finally write the 'mean QE_OFFSET value' to myMachine.h");
               trigged=1;
            }
#endif
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
            case PWMmod:
                if(fuse)
                    c_from_CDC :> VoutSet;
                else
                    c_from_CDC :> int _;
                break;
            case DRV_RESET:
                VoutSet=0;
                break;
            default:
                printstr("Error in FOC: Unknown command\n");
                break;
            }
            break;
        }
    }
}









