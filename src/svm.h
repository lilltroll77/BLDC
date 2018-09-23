/*
 * svm.h
 *
 *  Created on: 22 sep 2018
 *      Author: micke
 */
#ifndef SVM_H_
#define SVM_H_

#include <xs1.h>
#define SIN_TBL_BITS 10
#define SIN_TBL_LEN (1<<SIN_TBL_BITS)
#define CLKDIV 13
#define Tp (64*2*CLKDIV)
#define WRAP (SIN_TBL_LEN*6)
#define DECIMATE 128

void SVM(streaming chanend c_in , streaming chanend c_out);
void svpwm(streaming chanend c , clock clk , out port p_svm);

#endif /* SVM_H_ */
