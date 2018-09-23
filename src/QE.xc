/*
 * QE.xc
 *
 *  Created on: 21 sep 2018
 *      Author: micke
 */

#include "xs1.h"
#include "math.h"
#include <xscope.h>
#include <print.h>

#define QE_RES 8192

void QE(streaming chanend c , in port pA , in port pB , in port pX){
    int sin_tb[QE_RES];
    for(int i=0; i<QE_RES ; i++)
        sin_tb[i]=(double)0x7FFFFFFF*sin(2*M_PI *(double)i/QE_RES);

    int A,B=0;
    int angle=0*QE_RES/8;
    timer tmr;
    int t;
    pX when pinseq(0):>void;
    pX when pinseq(1):>void;

    //printchar('X');
    char token;
    while(1){
        tmr when timerafter(t + 100):>void; // debounce
        select{
        case pA when pinsneq(A) :> A:
            pB :> B;
            tmr:> t;
            if(A) // posedge
                angle = B ? angle-1 : angle+1;
            else // negedge
                angle = B ? angle+1 : angle-1;
            xscope_int(PROBE_ANGLE , angle & (QE_RES-1));
            break;
        case pB when pinsneq(B) :> B:
            pA :> A;
            tmr:> t;
            if(B)// posedge
                angle = A ? angle+1 : angle-1;
            else // negedge
                angle = A ? angle-1 : angle+1;
            xscope_int(PROBE_ANGLE , angle & (QE_RES-1));
            break;
        case c :> int _:
               int a = angle & (QE_RES-1);
               c<: sin_tb[a]; // sin(fi)
               a = (angle +(QE_RES/4)) & (QE_RES-1);
               c<: sin_tb[a]; // cos(fi)
        break;
        }

    }
    return;
}
