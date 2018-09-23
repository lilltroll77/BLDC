/*
 * wait.xc
 *
 *  Created on: 23 sep 2018
 *      Author: micke
 */

#include <xs1.h>

void wait(unsigned clk){
    timer tmr;
    int t;
    tmr:>t;
    tmr when timerafter(t + clk):>int _;
}
