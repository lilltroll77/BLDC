/*
 * typedefs.h
 *
 *  Created on: 23 sep 2018
 *      Author: Mikael Bohman
 */


#ifndef TYPEDEFS_H_
#define TYPEDEFS_H_


typedef struct{
    out buffered port:32 MOSI;
    in buffered port:32 MISO;
    out buffered port:32 CLK;
    out port CTRL;
    clock clkblk;
    int ctrl_val;
}SPI_t;

typedef struct{
   in port X;
   in port A;
   in port B;
}QE_t;

struct p_t{
    in buffered port:32 DATA_A;
    in buffered port:32 DATA_B;
    in buffered port:32 DATA_C;
    out port clk_A;
    out port clk_B;
    out port clk_C;
    clock clkBLOCK;
};


typedef struct{
    short t_before;
    short t1;
    short t2;
    short t0;
    short t_after;
    unsigned char p1;
    unsigned char p2;
    unsigned char zero;
}svm_t;

typedef int long long s64;
typedef unsigned long long u64;
typedef unsigned u32;

typedef struct{
     const int twoThird;
     const int m_oneThird;
     const int pow_Third;
 }c_t;

typedef struct{
    int power;
    int powerLP;
    int Af;
    int Bf;
    unsigned long long max_current;
    unsigned long long time_constant;
    unsigned fuse_current;
    unsigned overcurrent_holdValue;
    int overcurrent;
}current_t;

#endif /* TYPEDEFS_H_ */
