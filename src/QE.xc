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
#include "QE.h"

#define QE_RES 8192
#define DIRECTION (-1) // Can be 1 or (-1)

//Set this value to 0 during first calibration run
#define QE_OFFSET 274
#define UP   (QEdata.angle+DIRECTION)&(QE_RES-1)
#define DOWN (QEdata.angle-DIRECTION)&(QE_RES-1)

#define FOC_SECTORS 6

int translate(int fi){
    return ((FOC_SECTORS*7)*fi)%(FOC_SECTORS*8192)>>3;
}

void QE(streaming chanend c , in port pA , in port pB , in port pX , clock clk , struct QE_t &QEdata){
    set_core_high_priority_on();
    set_clock_div(clk , 25); //Create 2 MHz clock to handle debounce
    set_port_clock(pX , clk);
    set_port_clock(pA , clk);
    set_port_clock(pB , clk);
    start_clock(clk);

    int sin_tb[QE_RES];
    for(int i=0; i<QE_RES ; i++)
        sin_tb[i]=(double)0x7FFFFFFF*sin(2*M_PI *(double)i/QE_RES);

    int A=0,B=0,X=0;
    QEdata.angle=(8192-QE_OFFSET); // Reference angle
    unsigned t;
    timer tmr;
    char ct;
    int run=1;

    while(1){
        select{
        case pA when pinsneq(A) :> A:
            pB :> B;
            if(A) // posedge
                QEdata.angle = B ? DOWN : UP ;
            else // negedge
                QEdata.angle = B ? UP : DOWN ;
            c<: translate(QEdata.angle);
            break;
        case pB when pinsneq(B) :> B:
            pA :> A;
            if(B)// posedge
                QEdata.angle = A ? UP : DOWN ;
            else // negedge
                QEdata.angle = A ? DOWN : UP ;
            c<: translate(QEdata.angle);
            //printint(QEdata.angle);
            break;
         case pX when pinsneq(X):> X:
             if(X){
                 tmr :>t; //Simple to use a 32 bit timer instead of a 16 bit port timer, due to wraparound
                 QEdata.angle = (8192-QE_OFFSET); // Reference angle
                 QEdata.dt = t - QEdata.old_t;
                 QEdata.old_t = t;
             }
          break;
         case c:> int _:
             QEdata.angle=(8192-QE_OFFSET);
             c<: QEdata.angle;
         break;
    /*    case sinct_byref(c , ct):
            if(ct){
                c<:QEdata.angle;
                break;
            }
            int a = QEdata.angle;
            c<: sin_tb[a]; // sin(fi)
            a = (QEdata.angle +(QE_RES/4)) & (QE_RES-1);
            c<: sin_tb[a]; // cos(fi)

        break;
        */
        }

    }
    return;
}
