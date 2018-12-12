/*
 * FOC.h
 *
 *  Created on: 10 dec 2018
 *      Author: micke
 */

#ifndef FOC_H_
#define FOC_H_



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


#endif /* FOC_H_ */
