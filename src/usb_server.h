/*
 * usb_server.h
 *
 *  Created on: 10 dec 2018
 *      Author: micke
 */

#ifndef USB_SERVER_H_
#define USB_SERVER_H_
#include "cdc_handlers.h"

unsafe void usb_server(streaming chanend c_FOC2CDC , streaming chanend sc_GUI2RX , int* unsafe angle , client interface GUI_supervisor_interface supervisor_data );
unsafe void resetPointers(XUD_buffers_t &buffer);

#endif /* USB_SERVER_H_ */
