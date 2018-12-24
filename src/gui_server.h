/*
 * gui_server.h
 *
 *  Created on: 27 okt 2018
 *      Author: micke
 */


#ifndef GUI_SERVER_H_
#define GUI_SERVER_H_

enum pos_e{Slow , Pos , Vel , Perror , Reserved1 , Reserved2 , Reserved3 , Reserved4};
#define FFT_LEN (1<<18)

struct hispeed_t{
    int IA;
    int IC;
    int QE;
    int Torque;
    int Flux;
    int U;
    int angle;
   };


struct DSPmem_t{
    struct hispeed_t fast;
    //struct midspeed_t mid;
};

struct fuse_t{
    int current;
    int state;
    int max;
};

struct sharedMem_t{
    unsigned CPUload;
    struct DSPmem_t dsp[2];
};



#endif /* GUI_SERVER_H_ */
