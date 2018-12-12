/*
 * RX_block.h
 *
 *  Created on: 10 dec 2018
 *      Author: micke
 */

#ifndef RX_BLOCK_H_
#define RX_BLOCK_H_

#define PKG_SIZE 512 /*In bytes*/
#define CODEVERSION 1


struct midspeed_vector_t{
    int pos[PKG_SIZE/32];
    int vel[PKG_SIZE/32];
    int perror[PKG_SIZE/32];
    int reserved1[PKG_SIZE/32];
    int reserved2[PKG_SIZE/32];
    int reserved3[PKG_SIZE/32];
    int reserved4[PKG_SIZE/32];
};

struct hispeed_vector_t{
    int QE[PKG_SIZE/4];
    int IA[PKG_SIZE/4];
    int IC[PKG_SIZE/4];
    int Torque[PKG_SIZE/4];
    int Flux[PKG_SIZE/4];
    int U[PKG_SIZE/4];
    int angle[PKG_SIZE/4];
};

struct USBmem_t{
    unsigned long long checknumber; //2
    unsigned version; //3
    unsigned index; //4
    float temp; //5
    int states; //6
    unsigned DSPload;//7
    unsigned reserved[16-7]; // UPDATE if new line is inserted
    struct midspeed_vector_t mid;
    struct hispeed_vector_t fast;
};

unsafe void RX_block(streaming chanend c_from_gui , streaming chanend c_from_CDC , unsigned* unsafe angle);

#endif /* RX_BLOCK_H_ */
