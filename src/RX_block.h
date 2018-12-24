/*
 * RX_block.h
 *
 *  Created on: 10 dec 2018
 *      Author: micke
 */

#ifndef RX_BLOCK_H_
#define RX_BLOCK_H_
#include "QE.h"

#define PKG_SIZE 512 /*In bytes*/
#define CODEVERSION 2

enum fuse_state_e{fuse_REPLACE=-1 , fuse_BLOWNED=0, CT_PAUSE=1 /*IN USE 0-3*/ , fuse_GOOD=4 , fuse_NOCHANGE=5 , fuse_SETCURRENT=6};
#define CT_VERIFY 10

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
    unsigned changed; //5
    unsigned short DSPload; //5½
    unsigned short temp; //6
    unsigned short GateDrvStatus[6];// 7 8 9
    unsigned w; //10
    unsigned reserved[16-10]; // UPDATE if new line is inserted
    struct midspeed_vector_t mid;
    struct hispeed_vector_t fast;
};

unsafe void RX_block(streaming chanend c_from_gui , streaming chanend c_from_CDC , struct QE_t* unsafe QEptr);

#endif /* RX_BLOCK_H_ */
