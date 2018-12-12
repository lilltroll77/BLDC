/*
 * QE.xc
 *
 *  Created on: 21 sep 2018
 *      Author: Mikael Bohman
 */

#include "xs1.h"
#include "math.h"
#include <print.h>

#define QE_RES 8192

void QE(streaming chanend c , in port pA , in port pB , in port pX , unsigned QEangle[1]){
    set_core_high_priority_on();
    int sin_tb[QE_RES];
    for(int i=0; i<QE_RES ; i++)
        sin_tb[i]=(double)0x7FFFFFFF*sin(2*M_PI *(double)i/QE_RES);

    int A,B=0;
    QEangle[0]=8192-8192/(7*12); // Reference angle
    timer tmr;
    unsigned t;
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
                QEangle[0] = B ? QEangle[0]-1 : QEangle[0]+1;
            else // negedge
                QEangle[0] = B ? QEangle[0]+1 : QEangle[0]-1;
            break;
        case pB when pinsneq(B) :> B:
            pA :> A;
            tmr:> t;
            if(B)// posedge
                QEangle[0] = A ? QEangle[0]+1 : QEangle[0]-1;
            else // negedge
                QEangle[0] = A ? QEangle[0]-1 : QEangle[0]+1;
            //printint(QEangle[0]);
            break;

        case c :> int _:
               int a = QEangle[0] & (QE_RES-1);
               c<: sin_tb[a]; // sin(fi)
               a = (QEangle[0] +(QE_RES/4)) & (QE_RES-1);
               c<: sin_tb[a]; // cos(fi)
        break;
        }

    }
    return;
}
