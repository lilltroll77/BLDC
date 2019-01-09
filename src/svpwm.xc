/*
 * svpwm.xc
 *
 *  Created on: 22 sep 2018
 *      Author: Mikael Bohman
 */
#include "xs1.h"
#include "platform.h"
#include "svm.h"
#include "typedefs.h"
#include <print.h>
#define TRIGGER 1

on tile[0]: out port p_trigger = XS1_PORT_1P; //DS_B

void svpwm(streaming chanend c , clock clk , out port p_svm){
set_core_high_priority_on();
    int t=0;
    unsafe{
        svm_t* unsafe svm;
        set_port_clock(p_trigger , clk);
        c :> svm;


        start_clock(clk);


        while(1){
            t += svm->t_before;
            // start T1

            int dt1=svm->t1;
            if(dt1 !=0){
                p_svm @ t <: svm->p1;
                t += dt1;
            }

        {int dt2=svm->t2;
        if(dt2 !=0){
            p_svm @ t <: svm->p2;
            t += dt2;

            p_svm @ t <: svm->zero;
            t += svm->t0;

            p_svm @ t <: svm->p2;
            t += dt2;

        }else{
            p_svm @ t <: svm->zero;
            t += svm->t0;
        }}

        if(dt1 !=0){
            p_svm @ t <: svm->p1;
            t += dt1;
        }

        p_svm @ t<: svm->zero;
        t += svm->t_after;

        p_trigger <:0;
        c :> svm;
        p_trigger@t <:1;
        //printintln(svm->t0);

        } // while
    } //unsafe
}

