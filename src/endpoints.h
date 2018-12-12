/*
 * endpoints.h
 *
 *  Created on: 10 dec 2018
 *      Author: micke
 */

#ifndef ENDPOINTS_H_
#define ENDPOINTS_H_

#include "cdc_handlers.h"

struct type_t{
    unsigned char notification;
    unsigned char rx;
    unsigned char tx;
    unsigned char data;
};

struct descriptor_t{
    struct type_t intf;
    struct type_t EP;
};


unsafe void Endpoints(server interface cdc_if cdc[] , chanend chan_ep_out[] , XUD_buffers_t &buffer);


#endif /* ENDPOINTS_H_ */
