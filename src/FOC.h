/*
 * FOC.h
 *
 *  Created on: 10 dec 2018
 *      Author: micke
 */

#ifndef FOC_H_
#define FOC_H_
#include "typedefs.h"

#define FOC_MODE 1

#define PWM_MAX 37000
#define PWM_MIN ((PWM_MAX*5)/100) // 5%

//Warning a value of 8 has broken 2 gatedriver ICs!
#define dV_LIMIT 2 //Smaller value gives lower rate of change in the spacevector magnitude


struct state_t{
    s64 y1;
    s64 y2;
    int x1;
    int x2;
    unsigned error;
};

struct data64_t{
    unsigned lo;
    int hi;

};


unsafe void FOC(streaming chanend c_I[2] , streaming chanend c_fi , streaming chanend c_out , streaming chanend c_gui_server , streaming chanend c_from_CDC);
unsafe void gui_server(streaming chanend c_from_RX , streaming chanend c_from_dsp);


#endif /* FOC_H_ */
