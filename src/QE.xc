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


#define DIRECTION (-1) // Can be 1 or (-1)

#define QE_OFFSET 408
#define UP   (QEdata.angle+DIRECTION)&(QE_RES-1)
#define DOWN (QEdata.angle-DIRECTION)&(QE_RES-1)


int sin_tb[QE_RES+QE_RES/(4*MOTOR_MAG)];

void translate(int fi , streaming chanend c){
    int fi_out = ((FOC_SECTORS*MOTOR_MAG)*fi)%(FOC_SECTORS*QE_RES)>>3;
    int si = sin_tb[fi];
    fi += QE_RES/(4*MOTOR_MAG); // ADD 90 deg
    int co = sin_tb[fi];
    //master
    {
        c<: fi_out;
        c<: si; // sin(fi)
        c<: co; // cos(fi)
    }
}

void QE(streaming chanend c , streaming chanend c_fromCDC , in port pA , in port pB , in port pX , clock clk , struct QE_t &QEdata){
    set_core_high_priority_on();
    set_clock_div(clk , 25); //Create 2 MHz clock to handle debounce
    set_port_clock(pX , clk);
    set_port_clock(pA , clk);
    set_port_clock(pB , clk);
    start_clock(clk);


    for(int i=0; i<sizeof(sin_tb)/sizeof(int) ; i++)
        sin_tb[i]=(double)0x7FFFFFFF*sin(MOTOR_MAG*2*M_PI *(double)i/QE_RES);

    int A=0,B=0,X=0;
    QEdata.angle=0; // Reference angle
    unsigned t;
    timer tmr;
    char ct;
    int run=1;
    int trigged=0;
    int refAngle = (QE_RES-QE_OFFSET);
    while(1){
        select{
        case pA when pinsneq(A) :> A:
            pB :> B;
            if(A) // posedge
                QEdata.angle = B ? DOWN : UP ;
            else // negedge
                QEdata.angle = B ? UP : DOWN ;
#if(CALIBRATE_QE)
            if(trigged)
                c<:QEdata.angle;
#else
                translate(QEdata.angle , c);
#endif
            break;
        case pB when pinsneq(B) :> B:
            pA :> A;
            if(B)// posedge
                QEdata.angle = A ? UP : DOWN ;
            else // negedge
                QEdata.angle = A ? DOWN : UP ;
#if(CALIBRATE_QE)
            if(trigged)
                c<:QEdata.angle;
#else
                translate(QEdata.angle , c);
#endif
            //printint(QEdata.angle);
            break;
         case pX when pinsneq(X):> X:
             if(X){
                 tmr :>t; //Simple to use a 32 bit timer instead of a 16 bit port timer, due to wraparound
#if(CALIBRATE_QE)
                 QEdata.angle=0;
                 c<:QEdata.angle;
                 trigged=1;
#else
                 QEdata.angle = refAngle; // Reference angle
                 QEdata.dt = t - QEdata.old_t;
                 QEdata.old_t = t;
#endif
             }
          break;

         case c:> int _:
#if(CALIBRATE_QE)
             QEdata.angle = 1;
#else
             QEdata.angle = refAngle; // Reference angle
#endif
         break;
         case c_fromCDC :> int trim:
             refAngle = (QE_RES-QE_OFFSET)+ trim;
             break;

        }

    }
    return;
}
