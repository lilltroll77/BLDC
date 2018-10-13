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
#include "print.h"
#include "typedefs.h"

void SVM(streaming chanend c_in , streaming chanend c_out ){
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
    enum gate{HI_Z=0 , LO=1 , HI = 2};
    //from https://en.wikipedia.org/wiki/Space_vector_modulation
#define SV_LEN 8
    struct SpaceVector_t SpaceVector[SV_LEN]=
    {
            { HI , LO , LO },  // A -> B&C
            { HI , HI , LO },  // A&B -> C
            { LO , HI , LO },  // B -> A&C
            { LO , HI , HI },  // B&C -> A
            { LO , LO , HI },  // C -> A&B
            { HI , LO , HI },   // A&C -> B
            { HI , LO , LO },  // copy of first
            { LO , LO , LO }
    };


    char lut[SV_LEN];
    //Gatedriver & XMOS port8B format: See schematic
    for(int i=0; i< SV_LEN ; i++){
        lut[i] = (SpaceVector[i].phaseB) | (SpaceVector[i].phaseA<<2) | (SpaceVector[i].phaseC<<6);
        //printhexln(lut[i]);
    }
    svm[0].zero = sin_tb[SV_LEN-1];
    svm[1].zero = sin_tb[SV_LEN-1];

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

    c_in :>int _;
    unsigned counter=0;
    unsigned angle_set=1;
#pragma unsafe arrays
    int fi1=0;
    while(1){
        angle++;
        /*
        counter = (counter+1);
        if(counter==0){
            angle++;
            //xscope_int(ANGLE, sin_tb[fi1]);
        }else if(counter==1){
            angle_set--;
            if(angle_set == 0)
                angle_set = 8192*6;
        }

*/
        if(angle<0)
            angle += (6*SIN_TBL_LEN);
        else if(angle>= (6*SIN_TBL_LEN) )
            angle -= 6*SIN_TBL_LEN;

        int sector = angle>>SIN_TBL_BITS;

        svm[buffer].p1 = lut[sector];
        int fi2 = angle - (sector<<SIN_TBL_BITS);

        int next_sector = sector+1;
        svm[buffer].p2 = lut[next_sector];
         fi1 = (next_sector<<SIN_TBL_BITS) - angle;


        if((amp<0x7000) && buffer)//0x7000
            amp++;
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

        svm[buffer].t0 = Tp - svm[buffer].t1 - svm[buffer].t2;
        svm[buffer].t_before = svm[buffer].t0>>1;
        svm[buffer].t_after = svm[buffer].t0 - svm[buffer].t_before;

        unsafe{
            svm_t * unsafe ptr = &svm[buffer];
            //printchar('.');
            c_out <: ptr;
        }
        buffer = !buffer;

    }
}
