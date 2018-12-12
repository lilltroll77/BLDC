/*
 * calc.h
 *
 *  Created on: 17 nov 2018
 *      Author: micke
 */

#include "cdc_handlers.h"

#define FS (5e8/26/64)

struct PI_section_t{
    float Fc;
    float Gain;
    int P;
    int I;
};

enum filterType_t{Lead , Lead2 , Lag , Lag2 , Notch , AllPass , /* DISABLED ->*/ LP1 , LP2 , HP1 , HP2 , BandPass , PeakingEQ, Mute};

struct EQ_section_t{
        int active;
        enum filterType_t type;
        float Fc;
        float Q;
        float Gain;
        int B0;
        int B1;
        int B2;
        int A1;
        int A2;
};

void calcPI_fixedpoint(chanend c , struct PI_section_t &PI , int ch);
void calcEQ_fixedpoint(chanend c , struct EQ_section_t &EQ , int ch , int sec);
