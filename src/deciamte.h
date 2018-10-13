/*
 * deciamte.h
 *
 *  Created on: 4 okt 2018
 *      Author: micke
 */


#ifndef DECIAMTE_H_
#define DECIAMTE_H_

void decimate16(streaming chanend c_slow[2] , streaming chanend c_supervisor , current_t &I);
void decimate64(streaming chanend c , streaming chanend c_slow , in buffered port:32 p);

#endif /* DECIAMTE_H_ */
