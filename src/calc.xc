/*
 * calc.xc
 *
 *  Created on: 17 nov 2018
 *      Author: micke
 */

#include "calc.h"
#include "math.h"

void calcPI_fixedpoint(chanend c , struct PI_section_t &PI , int ch){
    PI.P = 20*log10f(PI.Gain/20);
    PI.I = 0; //UPDATE!
    c <: PIsection;
        master{
        c <: ch;
        c <: PI.P;
        c <: PI.I;
    }
}

void calcEQ_fixedpoint(chanend c , struct EQ_section_t &EQ , int ch , int sec){
    double w0 = 2 * M_PI * EQ.Fc/FS;
    double alpha=sin(w0)/(2 * EQ.Q);
    double A = pow(10 , EQ.Gain/40);
    double sqA = pow(10 , EQ.Gain/20);
    double w;
    double a0,a1,a2,b0,b1,b2;
    switch(EQ.type){
    case Notch:
        b0 =   1;
        b1 =  -2*cos(w0);
        b2 =   1;
        a0 =   1 + alpha;
        a1 =  -2*cos(w0);
        a2 =   1 - alpha;
        break;
    case Lead:
        w = 2 * M_PI * EQ.Fc;
        b0 = 2*FS + w*sqA;
        b1 = w*sqA - 2*FS;
        b2 = 0;
        a0 = 2*FS + w;
        a1 = w - 2*FS;
        a2 = 0;
        break;
    case Lead2:
        b0 =    A*( (A+1) - (A-1)*cos(w0) + 2*sqrt(A)*alpha );
        b1 =  2*A*( (A-1) - (A+1)*cos(w0)                   );
        b2 =    A*( (A+1) - (A-1)*cos(w0) - 2*sqrt(A)*alpha );
        a0 =        (A+1) + (A-1)*cos(w0) + 2*sqrt(A)*alpha;
        a1 =   -2*( (A-1) + (A+1)*cos(w0)                   );
        a2 =        (A+1) + (A-1)*cos(w0) - 2*sqrt(A)*alpha;
        break;
    case Lag:
        w = 2 * M_PI * EQ.Fc;
        b0 = w - 2*sqA*FS;
        b1 = 2*sqA*FS +w;
        b2 = 0;
        a0 = 2*FS + w;
        a1 = w - 2*FS;
        a2 = 0;
        break;
    case Lag2:
        b0 =    A*( (A+1) + (A-1)*cos(w0) + 2*sqrt(A)*alpha );
        b1 = -2*A*( (A-1) + (A+1)*cos(w0)                   );
        b2 =    A*( (A+1) + (A-1)*cos(w0) - 2*sqrt(A)*alpha );
        a0 =        (A+1) - (A-1)*cos(w0) + 2*sqrt(A)*alpha;
        a1 =    2*( (A-1) - (A+1)*cos(w0)                   );
        a2 =        (A+1) - (A-1)*cos(w0) - 2*sqrt(A)*alpha;
        break;
    default:
        break;
    }
    a0 *= pow(2 , -30);
    EQ.B0 = b0/a0;
    EQ.B1 = b1/a0;
    EQ.B2 = b2/a0;
    EQ.A1 = a1/a0;
    EQ.A2 = a2/a0;

    c <: EQsection;
    master{
        c <: ch;
        c <: sec;
        c <: EQ.B0;
        c <: EQ.B1;
        c <: EQ.B2;
        c <: EQ.A1;
        c <: EQ.A2;
    }
}
