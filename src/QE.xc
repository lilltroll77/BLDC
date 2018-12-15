/*
 * QE.xc
 *
 *  Created on: 21 sep 2018
 *      Author: Mikael Bohman
 */

#include "xs1.h"
#include "math.h"
#include <print.h>
#include "FOC.h"

#define QE_RES 8192
#define DIRECTION (-1) // Can be 1 or (-1)

//Set this value to 0 during first calibration run
#define QE_OFFSET 274

void QE(streaming chanend c , in port pA , in port pB , in port pX , unsigned QEangle[1]){
    set_core_high_priority_on();
    int sin_tb[QE_RES];
    for(int i=0; i<QE_RES ; i++)
        sin_tb[i]=(double)0x7FFFFFFF*sin(2*M_PI *(double)i/QE_RES);

    int A=0,B=0,X=0;
    QEangle[0]=(8192-QE_OFFSET); // Reference angle
    timer tmr;
    unsigned t;
    char ct;
    int run=1;
    pX:> X;
    while(run){
        select{
        case pX when pinsneq(X):>X:
            //printintln(X);
            if(X)
                run=0;
            break;
        case sinct_byref(c , ct):
            c<:-1;
            break;

        }
    }

    tmr:> t;
    while(1){
        tmr when timerafter(t + 100):>void; // debounce
        select{
        case pA when pinsneq(A) :> A:
            pB :> B;
            tmr:> t;
            if(A) // posedge
                QEangle[0] = B ? QEangle[0]-DIRECTION : QEangle[0]+DIRECTION;
            else // negedge
                QEangle[0] = B ? QEangle[0]+DIRECTION : QEangle[0]-DIRECTION;
            break;
        case pB when pinsneq(B) :> B:
            pA :> A;
            tmr:> t;
            if(B)// posedge
                QEangle[0] = A ? QEangle[0]+DIRECTION : QEangle[0]-DIRECTION;
            else // negedge
                QEangle[0] = A ? QEangle[0]-DIRECTION : QEangle[0]+DIRECTION;
            //printint(QEangle[0]);
            break;
         case pX when pinsneq(X):>X:
             if(X)
                 QEangle[0]=(8192-QE_OFFSET); // Reference angle
         break;
        case sinct_byref(c , ct):
                if(ct){
                    c<:QEangle[0] & (QE_RES-1);
                    break;
                }
        int a = QEangle[0] & (QE_RES-1);
        c<: sin_tb[a]; // sin(fi)
        a = (QEangle[0] +(QE_RES/4)) & (QE_RES-1);
        c<: sin_tb[a]; // cos(fi)

        break;
        }

    }
    return;
}
