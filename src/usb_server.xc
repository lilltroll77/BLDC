
/*
 * usb_server.xc
 *
 *  Created on: 27 okt 2018
 *      Author: micke
 */

#include "usb.h"
#include "cdc_handlers.h"
#include "endpoints.h"
#include "RX_block.h"

unsafe void resetPointers(XUD_buffers_t &buffer){
    // init all read and write pointers to the beginning of the corresponding FIFO
    buffer.rx.read1 =  buffer.rx.fifo1;
    buffer.rx.write1 = buffer.rx.fifo1;
    buffer.rx.fifoLen1 = buffer.rx.fifo2;

    buffer.tx.read1 =  buffer.tx.fifo1;
    buffer.tx.write1 = buffer.tx.fifo1;
}


unsafe void usb_server(streaming chanend c_FOC2CDC , streaming chanend sc_GUI2RX , struct QE_t* unsafe QEptr , client interface GUI_supervisor_interface supervisor_data ){
    chan c_ep_out[XUD_EP_COUNT_OUT], c_ep_in[XUD_EP_COUNT_IN];
    streaming chan sc_CDC2RX;
    interface cdc_if cdc[1];

        XUD_buffers_t buffer={0};
        unsafe{
            resetPointers(buffer);
        par{
                {
                    set_core_high_priority_on();
                    xud(c_ep_out, XUD_EP_COUNT_OUT, c_ep_in, XUD_EP_COUNT_IN , null ,  XUD_SPEED_HS, XUD_PWR_SELF);
                }
            {
                //Init all endpoints in XUD
                int etype;
                for(int i=0 ; i <XUD_EP_COUNT_OUT; i++){
                    switch(i){
                    case 0:
                        etype= XUD_EPTYPE_CTL | XUD_STATUS_ENABLE;
                        break;
                    case 1:
                        etype = XUD_EPTYPE_BUL | XUD_STATUS_ENABLE;
                        break;
                    default:
                        etype = XUD_EPTYPE_BUL;
                        break;

                    }
                    buffer.rx.ep[i] = XUD_InitEp(c_ep_out[i] , etype);
                }// for


                for(int i=0 ; i <XUD_EP_COUNT_IN; i++){
                    switch(i){
                    case 0:
                        etype= XUD_EPTYPE_CTL | XUD_STATUS_ENABLE;
                        break;
                    case 1:
                        etype= XUD_EPTYPE_BUL | XUD_STATUS_ENABLE;
                        break;
                    case 2:
                        etype= XUD_EPTYPE_INT; //Only used for setup !?
                        break;
                    case 3:
                        etype= XUD_EPTYPE_BUL;
                        break;
                    default:
                        etype = i&1 ? XUD_EPTYPE_BUL : XUD_EPTYPE_INT;
                        break;
                    }
                    buffer.tx.ep[i]  = XUD_InitEp(c_ep_in[i]  , etype );
                } // for


                XUD_buffers_t* unsafe buffer_ptr = &buffer;
                par{
                    Endpoints(cdc , c_ep_out ,  buffer);
                    cdc_handler1(cdc[0] , supervisor_data  , c_FOC2CDC , sc_CDC2RX, c_ep_in , buffer_ptr);
                    RX_block(sc_GUI2RX , sc_CDC2RX , QEptr );
                }

            }//guards
        }
    }
}
