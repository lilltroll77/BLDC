/*
 * cdc_handlers.h
 *
 *  Created on: 10 dec 2018
 *      Author: micke
 */
#ifndef CDC_HANDLERS_H_
#define CDC_HANDLERS_H_


#include "xud.h"
#include "supervisor.h"

#define FIFO1_LEN 1024
#define FIFO2_LEN 64
#define BLOCKSIZE 64
#define N_CDC 0 // Needs clean -> build after change
#define XUD_EP_COUNT_OUT ( 2 + N_CDC)
#define XUD_EP_COUNT_IN  (2+ 2*N_CDC)


interface cdc_if{
   [[notification]] slave void data_available(void);
   [[clears_notification]] void queue_empty(void);
};



//recieve data from host -OUT
struct XUDbufferRx_t{
    int* unsafe write1;
    int* unsafe write2;
    int* unsafe read1;
    int* unsafe read2;
    int* unsafe fifoLen1;
    int* unsafe fifoLen2;
    unsigned pkg_maxSize1;
    unsigned pkg_maxSize2;
    unsigned queue_len1;
    unsigned queue_len2;
    XUD_ep ep[XUD_EP_COUNT_OUT];
    int fifo1[FIFO1_LEN];
    int fifo2[FIFO2_LEN];
};


//transmit data to host -IN
struct XUDbufferTx_t{
    int* unsafe write1;
    int* unsafe write2;
    int* unsafe read1;
    int* unsafe read2;
    unsigned ready1;
    unsigned ready2;
    unsigned dataWaiting1;
    unsigned dataWaiting2;
    unsigned queue_len1;
    unsigned queue_len2;
    XUD_ep ep[XUD_EP_COUNT_IN];
    int fifo1[FIFO1_LEN];
    int fifo2[FIFO2_LEN];
};

typedef struct{
    struct XUDbufferTx_t tx;
    struct XUDbufferRx_t rx;
    int reset_N;
}XUD_buffers_t;

struct EQ_t{
    int B0;
    int B1;
    int B2;
    int A1;
    int A2;
    int shift;
};

struct regulator_t{
    int I;
    int P;
    struct EQ_t EQ[2];
};

#define CT 4

enum INstatus_e{InEPready=-2 , BufferWritten=-1 , BufferReadyToWrite=0};
enum message_e{streamOUT, PIsection , EQsection , resetPI , resetEQsec , resetEQ , FuseCurrent , NewFuse , FuseStatus , SignalSource , SignalGenerator,
               DRV_IDRIVE_P_HS , DRV_IDRIVE_N_HS,
               DRV_TDRIVE, DRV_IDRIVE_P_LS , DRV_IDRIVE_N_LS ,
               DRV_DEADTIME , DRV_OCP_DEG , DRV_VDS_LVL ,
               DRV_RESET};
enum signal_e{OFF , MLS18 , RND , SINE , OCTAVE};


unsafe void cdc_handler1(client interface cdc_if cdc ,  client interface GUI_supervisor_interface supervisor  , streaming chanend c_from_dsp , streaming chanend c_from_RX , chanend c_ep_in[], XUD_buffers_t * unsafe buff);


#endif /* CDC_HANDLERS_H_ */
