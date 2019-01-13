/*
 * qe.h
 *
 *  Created on: 17 dec 2018
 *      Author: micke
 */

#ifndef QE_H_
#define QE_H_

#define QE_RES 8192
#define FOC_SECTORS 6
#define MOTOR_MAG 7


struct QE_t{
    unsigned angle;
    unsigned dt;
    unsigned old_t;
};

void QE(streaming chanend c_out , streaming chanend c_fromCDC , in port pA , in port pB , in port pX , clock clk , struct QE_t &QEdata);


#endif /* QE_H_ */