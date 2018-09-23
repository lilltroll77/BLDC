/*
 * pwm.xc
 *
 *  Created on: 22 sep 2018
 *      Author: micke
 */
#include "xs1.h"
#include "svm.h"


void pwm(clock clk , out port p_A , out port p_B , out port p_C  ,streaming chanend c){
    int t=50;
    p_A <:0;
    p_C <:0;
    p_B <:0;
/*
    #define LEN (8192*8)
    short sin_tb[LEN];
    for(int i=0; i<LEN ; i++)
        sin_tb[i]=50 + (CYCLES-400)/2*(1 - cos(2*M_PI *(double)i / LEN ));

    int i=0;
*/

    int dt=Tp;
    p_C <:1;
    p_B <:1;
    c :> dt;
    start_clock(clk);
    while(1){
        select{
        case c :> dt:
            break;

        default:
            t +=dt;
            p_A @ t <:1;
            t +=(Tp-dt);
            p_A @ t <:2;
            break;
        }
    }
}
