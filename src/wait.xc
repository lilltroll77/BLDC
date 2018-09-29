/*
 * wait.xc
 *
 *  Created on: 23 sep 2018
 *      Author: Mikael Bohman
 */

#include <xs1.h>

void wait(unsigned clk){
    timer tmr;
    unsigned t;
    tmr:>t;
    tmr when timerafter(t + clk):>int _;
}
