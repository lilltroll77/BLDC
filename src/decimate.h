/*
 * decimate.h
 *
 *  Created on: 19 dec 2018
 *      Author: micke
 */

#ifndef DECIMATE_H_
#define DECIMATE_H_

#define FIRLEN 512
#define WORD_SIZE 8
#define SIZE (1<<WORD_SIZE)
#define BLOCKS (FIRLEN/WORD_SIZE)
#define FIFO_INT (FIRLEN/32)




void init_dec_tb();
void decimate64(streaming chanend c , in buffered port:32 p , int offset);

#endif /* DECIMATE_H_ */
