/*
 * ControlInterfaceCalssRequest.xc
 *
 *  Created on: 24 okt 2018
 *      Author: micke
 */
#include "descriptors.h"

/* CDC Communications Class requests */
#define CDC_SET_LINE_CODING         0x20
#define CDC_GET_LINE_CODING         0x21
#define CDC_SET_CONTROL_LINE_STATE  0x22
#define CDC_SEND_BREAK              0x23

/* CDC Class-specific requests handler function */
XUD_Result_t ControlInterfaceClassRequests(XUD_ep ep_out, XUD_ep ep_in, USB_SetupPacket_t sp)
{
    /* Word aligned buffer */
    unsigned int buffer[32];
    unsigned length;
    XUD_Result_t result;

    static struct LineCoding {
        unsigned int baudRate;
        unsigned char charFormat;
        unsigned char parityType;
        unsigned char dataBits;
    }lineCoding;

    static struct lineState {
        unsigned char dtr;
        unsigned char rts;
    } lineState;

#if defined (DEBUG) && (DEBUG == 1)
    printhexln(sp.bRequest);
#endif

    switch(sp.bRequest)
    {
        case CDC_SET_LINE_CODING:

            if((result = XUD_GetBuffer(ep_out, (buffer, unsigned char[]), length)) != XUD_RES_OKAY)
            {
                return result;
            }

            lineCoding.baudRate = buffer[0];    /* Read 32-bit baud rate value */
            lineCoding.charFormat = (buffer, unsigned char[])[4]; /* Read one byte */
            lineCoding.parityType = (buffer, unsigned char[])[5];
            lineCoding.dataBits = (buffer, unsigned char[])[6];

            result = XUD_DoSetRequestStatus(ep_in);

            #if defined (DEBUG) && (DEBUG == 1)
            printf("Baud rate: %u\n", lineCoding.baudRate);
            printf("Char format: %d\n", lineCoding.charFormat);
            printf("Parity Type: %d\n", lineCoding.parityType);
            printf("Data bits: %d\n", lineCoding.dataBits);
            #endif
            return result;

            break;

        case CDC_GET_LINE_CODING:

            buffer[0] = lineCoding.baudRate;
            (buffer, unsigned char[])[4] = lineCoding.charFormat;
            (buffer, unsigned char[])[5] = lineCoding.parityType;
            (buffer, unsigned char[])[6] = lineCoding.dataBits;

            return XUD_DoGetRequest(ep_out, ep_in, (buffer, unsigned char[]), 7, sp.wLength);

            break;

        case CDC_SET_CONTROL_LINE_STATE:

            /* Data present in wValue */
            lineState.dtr = sp.wValue & 0x01;
            lineState.rts = (sp.wValue >> 1) & 0x01;

            /* Acknowledge */
            result =  XUD_DoSetRequestStatus(ep_in);

            #if defined (DEBUG) && (DEBUG == 1)
            printf("DTR: %d\n", lineState.dtr);
            printf("RTS: %d\n", lineState.rts);
            #endif

            return result;

            break;

        case CDC_SEND_BREAK:
            /* Send break signal on UART (if requried) */
            // sp.wValue says the number of milliseconds to hold in BREAK condition
            return XUD_DoSetRequestStatus(ep_in);

            break;

        default:
            // Error case
            printhexln(sp.bRequest);
            break;
    }
    return XUD_RES_ERR;
}
