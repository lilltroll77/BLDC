/*
 * FOC.xc
 *
 *  Created on: 23 sep 2018
 *      Author: Mikael Bohman
 */

#include "svm.h"
#include "xs1.h"
#include "typedefs.h"
#include <xscope.h>
#include "print.h"
#include "stdlib.h"
#include "typedefs.h"

void FOC(streaming chanend c_I[2] , streaming chanend c_fi , streaming chanend c_out , streaming chanend c_FIFO , streaming chanend c_supervisor ,current_t &I ){
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

    I.release_time = (0xFFFFFFFF-(1<<7));
    I.overcurrent =0;
    I.max=0;
    c_out <:0;

    while(1){
        char ct;
        int Iin;
        unsigned Ihold;
        c_fi <: 0;
        c_I[0]:>Iin;
        I.A = (Iin - Offset);
        c_I[1]:>Iin;
        I.C = (Iin - Offset);
        I.B = -(I.A+I.C);
        int fi;

        unsigned abs_IA = abs(I.A);
        unsigned abs_IC = abs(I.C);
        if(I.max < abs_IA)
            I.max = abs_IA;
        else if(I.max < abs_IC)
            I.max = abs_IC;
        else{
            unsigned lo;
            {I.max , lo} =mac(I.max , I.release_time , 0 , 0);
        }

        if((I.max > I.fuse) & (I.overcurrent==0)){
            I.overcurrent=1;
            soutct(c_supervisor , 0);
        }


        c_t c={1431655765 , -1431655765/2 , 1239850262};

        // 3 to 2 transform

        int Ahi , Bhi;
        unsigned Alo , Blo;

        {Ahi , Alo} = macs(I.A , c.twoThird , 0 ,0);
        {Ahi , Alo} = macs(I.B + I.C , c.m_oneThird , Ahi , Alo);
        {Bhi , Blo} = macs(I.B-I.C , c.pow_Third , 0 ,0);

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

        {Id , Id_lo} = macs(Ahi , cos_fi , 0 , 0);
        {Id , Id_lo} = macs(Bhi , sin_fi , Id , Id_lo);


    }

}
