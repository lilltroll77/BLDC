/*
 * FOC.xc
 *
 *  Created on: 23 sep 2018
 *      Author: Mikael Bohman
 */

#include "svm.h"
#include "xs1.h"
#include <xscope.h>
#include "print.h"
#include "stdlib.h"
#include "typedefs.h"

extern unsigned Amp2FixPoint(float I);

#define RMS_SHIFT 13
#define DEC_BITS 4


enum phases{A,C,B};

void FOC(streaming chanend c_I[2] , streaming chanend c_fi , streaming chanend c_out , streaming chanend c_FIFO , streaming chanend c_supervisor ){
    //dec^3/2 + tri


    c_out <:0;
    sinct(c_I[0]); // wait for ADC0 to stab.
    sinct(c_I[1]); // wait for ADC1 to stab.
    soutct(c_I[0], 5); // tell ADC0 to start sampling
    soutct(c_I[1], 5); // tell ADC1 to start sampling

    int i[3];

    int cnt=0;
    while(1){
        char ct;
        int Iin;
        unsigned Ihold;
        c_fi <: 0;
        c_I[A] :> i[A];
        c_I[C] :> i[C];
        i[B] = -(i[A]+i[C]);
        int fi;


        c_t c={1431655765 , -1431655765/2 , 1239850262};

        // 3 to 2 transform

        int Ahi , Bhi;
        unsigned Alo , Blo;

        {Ahi , Alo} = macs(i[A] , c.twoThird , 0 ,0);
        {Ahi , Alo} = macs(i[B] + i[C] , c.m_oneThird , Ahi , Alo);
        {Bhi , Blo} = macs(i[B]- i[C] , c.pow_Third , 0 ,0);

        int cos_fi , sin_fi;
        c_fi:> sin_fi;
        c_fi:> cos_fi;

        //printchar(',');

        int Id , Iq;
        unsigned Id_lo , Iq_lo;

        {Id , Id_lo} = macs(Ahi , cos_fi , 0 , 0);
        {Id , Id_lo} = macs(Bhi , sin_fi , Id , Id_lo);

        {Iq , Iq_lo} = macs(-Ahi , sin_fi , 0 , 0);
        {Iq , Iq_lo} = macs(Bhi ,  cos_fi , Iq , Iq_lo);


        Id = Id<<2 | Id_lo>>30;
        Iq = Iq<<2 | Iq_lo>>30;

        if(cnt==0)
            c_FIFO <: Id;
        else
            c_FIFO <: Iq;
        cnt = !cnt;

        //{Id , Id_lo} = macs(Ahi , cos_fi , 0 , 0);
        //{Id , Id_lo} = macs(Bhi , sin_fi , Id , Id_lo);


    }//while

}
