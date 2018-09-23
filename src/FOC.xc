/*
 * FOC.xc
 *
 *  Created on: 23 sep 2018
 *      Author: micke
 */

#include "svm.h"
#include "xs1.h"
#include "typedefs.h"
#include <xscope.h>
#include "print.h"

void FOC(streaming chanend c_I[2] , streaming chanend c_fi , streaming chanend c_out , streaming chanend c_FIFO ){
    int Offset=  DECIMATE*DECIMATE*DECIMATE/2; //dec^3/2 + tri


    /*{
        unsigned Alo=0 , Clo=0;
        const unsigned samples=1<<16;
        for(unsigned i=0; i<samples ; i++){
            unsigned I;
            c_I[0]:> I;
            {OffsetA , Alo} = mac(1<<(32-16), I , OffsetA ,Alo);
            c_I[1]:> I;
            {OffsetC , Clo} = mac(1<<(32-16), I , OffsetC ,Clo);
        }

    printuintln(OffsetA);
    printuintln(OffsetC);
    //c_out <:0;
    }
    */
    c_out <:0;
    while(1){
        int I;
        c_fi <: 0;
        c_I[0]:>I;
        int I_A = (I - Offset)<<2;
        c_I[1]:>I;
        int I_C = (I - Offset)<<2;
        int I_B = -I_A-I_C;
        int fi;


        c_t c={1431655765 , -1431655765/2 , 1239850262};

          // 3to2 transform


        int Ahi , Bhi;
        unsigned Alo , Blo;

        {Ahi , Alo} = macs(I_A , c.twoThird , 0 ,0);
        {Ahi , Alo} = macs(I_B + I_C , c.m_oneThird , Ahi , Alo);
        {Bhi , Blo} = macs(I_B-I_C , c.pow_Third , 0 ,0);

        int cos_fi , sin_fi;
        c_fi:> sin_fi;
        c_fi:> cos_fi;


        int Id , Iq;
        unsigned Id_lo , Iq_lo;

        {Id , Id_lo} = macs(Ahi , cos_fi , 0 , 0);
        {Id , Id_lo} = macs(Bhi , sin_fi , Id , Id_lo);

        {Iq , Iq_lo} = macs(-Ahi , sin_fi , 0 , 0);
        {Iq , Iq_lo} = macs(Bhi ,  cos_fi , Id , Id_lo);

        c_FIFO <: Id;
        c_FIFO <: Iq;


    }

}
