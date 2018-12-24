/*
 * qe.h
 *
 *  Created on: 17 dec 2018
 *      Author: micke
 */

#ifndef QE_H_
#define QE_H_


struct QE_t{
    unsigned angle;
    unsigned dt;
    unsigned old_t;
};

void QE(streaming chanend c_out , in port pA , in port pB , in port pX , clock clk , struct QE_t &QEdata);


#endif /* QE_H_ */
