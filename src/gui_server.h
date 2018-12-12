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
    unsigned CPUload;
    unsigned FFTtrig;
};


struct DSPmem_t{
    struct hispeed_t fast;
    //struct midspeed_t mid;
};

struct fuse_t{
    int current;
    int state;
};

struct sharedMem_t{
    struct fuse_t fuse;
    struct DSPmem_t dsp[2];
};

unsafe void gui_server(streaming chanend c_from_RX , streaming chanend c_from_dsp);


#endif /* GUI_SERVER_H_ */
