/*
 * SVM.xc
 *
 *  Created on: 22 sep 2018
 *      Author: Mikael Bohman
 */
#include "xs1.h"
#include "xclib.h"
#include "svm.h"
#include <xscope.h>
#include "math.h"
#include "stdio.h"
#include "typedefs.h"
#include "gui_server.h"
#include "foc.h"


unsafe void SVM(streaming chanend c_in , streaming chanend c_out ){
    int sin_tb[SIN_TBL_LEN+2];
    svm_t svm[2]={0};

    int angle=0;
    unsigned e1=0,e2=0;
    int amp=0;
    int buffer=0;

    //Switching vector
    struct SpaceVector_t{
        char phaseA;
        char phaseB;
        char phaseC;
    };
    enum gate{HI_Z=0 , LO=0b01 , HI = 0b10};
    //from https://en.wikipedia.org/wiki/Space_vector_modulation
#define SV_LEN 9
#define BRAKE (SV_LEN-2)
    struct SpaceVector_t SpaceVector[SV_LEN]=
    {
            { HI , LO , LO },  //1. A -> B&C
            { HI , HI , LO },  //2. A&B -> C
            { LO , HI , LO },  //3. B -> A&C
            { LO , HI , HI },  //4. B&C -> A
            { LO , LO , HI },  //5. C -> A&B
            { HI , LO , HI },  //6. A&C -> B
            { HI , LO , LO },  // copy of 1
            { LO , LO , LO },  // BRAKE
            { HI_Z , HI_Z , HI_Z },  // COAST
    };


    char lut[SV_LEN];
    //Gatedriver & XMOS port8B format: See schematic
    for(int i=0; i< SV_LEN ; i++){
        lut[i] = (SpaceVector[i].phaseB) | (SpaceVector[i].phaseA<<2) | (SpaceVector[i].phaseC<<6);
        printf("%d: 0x%x\n",i,lut[i]);
    }
    svm[0].zero = lut[BRAKE];
    svm[1].zero = lut[BRAKE];

    double A = sqrt(3)*Tp * (1<<16);
       for(int i=0; i < sizeof(sin_tb)>>2  ; i++)
           sin_tb[i]= round( A*sin((M_PI/3/(SIN_TBL_LEN+1))*(double) i));

    int t1=0,t2=0;
    const int limit=30;
    int dir=1;
    /*int fi1_pre=(sector+1)*SIN_TBL_LEN;
    int fi2_post = sector*SIN_TBL_LEN;
    svm[0].p1 = lut[sector];
    svm[1].p1 = lut[sector];
    svm[0].p2 = lut[next_sector];
    svm[1].p2 = lut[next_sector];
*/
    struct hispeed_t* unsafe mem[2];
    c_in :> mem[0];
    c_in :> mem[1];
    c_in <: angle;
    unsigned counter=0;
#pragma unsafe arrays
    int sector , next_sector, diff;
    while(1){
        select{
            //For development. If FOC core does not send data in time, the old data will be used.
        case c_in :> angle:
            if(angle<0)
                angle += WRAP;
            else if(angle >= WRAP)
                angle -= WRAP;
            c_in <: angle;

            sector = (angle>>SIN_TBL_BITS); // [0 - 5]
            next_sector = sector+1; // [1-6]


            c_in :> amp;
       break;
        default:
#if(0)
        select{
            case c_in :> int df:
                angle +=df;
                c_in <: angle;
                break;
            default:
                amp=0x6500;
                buffer=0;
                break;
        }
#else
#endif


        //c_in :> mem;
        mem[buffer]->angle = angle;
        mem[buffer]->U = amp;

        if(amp==0){
            //ADC will loose supply voltage if output is free floating
            svm[buffer].p1 = lut[BRAKE];
            svm[buffer].p2 = lut[BRAKE];
            svm[buffer].t1=100;
            svm[buffer].t2=100;
        }
        else{




        int fi2 = angle & (SIN_TBL_LEN-1); // 0 - 60 deg within sector
        svm[buffer].p2 = lut[next_sector];


        svm[buffer].p1 = lut[sector];
        int fi1 = SIN_TBL_LEN - fi2; // complement 60 - fi2



        { t1, e1} = macs( amp , sin_tb[fi1] , t1 , e1);
        if(t1<(limit/2) )
            svm[buffer].t1=0;
        else if(t1<limit){
            svm[buffer].t1=limit;
            t1 -= limit;
        }
        else{
            svm[buffer].t1=t1;
            t1 =0;
        }
        { t2, e2} = macs( amp , sin_tb[fi2] , t2, e2);
        //printintln(fi2);
        if(t2< (limit/2) )
            svm[buffer].t2=0;
        else if(t2<limit){
            svm[buffer].t2=limit;
            t2 -= limit;
        }else{
            svm[buffer].t2=t2;
            t2=0;
        }
        }
        svm[buffer].t0 = Tp - svm[buffer].t1 - svm[buffer].t2;
        svm[buffer].t_before = svm[buffer].t0>>1;
        svm[buffer].t_after = svm[buffer].t0 - svm[buffer].t_before;

        //xscope_short(PROBE_T0, svm[buffer].t0);
        //xscope_short(PROBE_T1, svm[buffer].t1);
        //xscope_short(PROBE_T2, svm[buffer].t2);
        /*
        xscope_int(PROBE_ANGLE, alfa);
        xscope_int(PROBE_FI1, fi1);
        xscope_int(PROBE_FI2, fi2);
*/
        //xscope_int(PROBE_ANGLE, alfa);
        unsafe{
            svm_t * unsafe ptr = &svm[buffer];
            //printchar('.');
            c_out <: ptr;
        }
        buffer = !buffer;
        break;
        }


    }
}
//svm[buffer].p = (lut[sector]) | (lut[sector]<<16) | (lut[next_sector]<<8);
 //(svm[buffer].p , char[])[1] = lut[sector];
 //(svm[buffer].p , char[])[3] = lut[sector];
 //(svm[buffer].p , char[])[2] = lut[next_sector];
