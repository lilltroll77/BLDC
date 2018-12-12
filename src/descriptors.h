/*
 * descriptors.h
 *
 *  Created on: 23 okt 2018
 *      Author: micke
 */
#include "usb.h"
#include "RX_block.h"
#include "cdc_handlers.h"

#ifndef DESCRIPTORS_H_
#define DESCRIPTORS_H_

#define BCD_DEVICE              0x1000
#define VENDOR_ID               0x20B1
#define PRODUCT_ID              0x00DA
#define MANUFACTURER_STR_INDEX  0x0001
#define PRODUCT_STR_INDEX       0x0002

/* Vendor specific class defines */
#define VENDOR_SPECIFIC_CLASS    0xff
#define VENDOR_SPECIFIC_SUBCLASS 0x00
#define VENDOR_SPECIFIC_PROTOCOL 0x00

//Interface Association Descriptor
#define USB_IAD 0x0B

/* USB Sub class and protocol codes */
#define USB_CDC_ACM_SUBCLASS        0x02
#define USB_CDC_AT_COMMAND_PROTOCOL 0x01

/* CDC interface descriptor type */
#define USB_DESCTYPE_CS_INTERFACE   0x24


#define UPDATE 0

#define STRINGINDEX 0x00

static unsigned char IAD_CDC[]={
        //Interface Association Descriptor1
          0x08,                          // bLength
          USB_IAD,                       // bDescriptorType
          1,                             // BYTE  bFirstInterface !!UPDATE@2!!
          0x02,                          // bInterfaceCount  //  CDC Communication interface +  CDC DATA interface
          USB_CLASS_COMMUNICATIONS,      // bFunctionClass
          USB_CDC_ACM_SUBCLASS,          // bFunctionSubClass
          USB_CDC_AT_COMMAND_PROTOCOL,   // bFunctionProtocol
          0x00                           // Interface string index
};

static unsigned char CDC[]={
        /* CDC Communication interface */
           0x09,                       /* 0  bLength */
           USB_DESCTYPE_INTERFACE,     /* 1  bDescriptorType - Interface */
           UPDATE,                     /* 2  bInterfaceNumber - Interface 0 */ //!!UPDATE@2!!
           0x00,                       /* 3  bAlternateSetting */
           0x01,                       /* 4  bNumEndpoints */
           USB_CLASS_COMMUNICATIONS,   /* 5  bInterfaceClass */
           USB_CDC_ACM_SUBCLASS,       /* 6  bInterfaceSubClass - Abstract Control Model */
           USB_CDC_AT_COMMAND_PROTOCOL,/* 7  bInterfaceProtocol - AT Command V.250 protocol */
           0x00,                       /* 8  iInterface - No string descriptor */

           /* Header Functional descriptor */
 /*9*/     0x05,                      /* 0  bLength */
           USB_DESCTYPE_CS_INTERFACE, /* 1  bDescriptortype, CS_INTERFACE */
           0x00,                      /* 2  bDescriptorsubtype, HEADER */
           0x10, 0x01,                /* 3  bcdCDC */

           /* ACM Functional descriptor */
/*14*/     0x04,                      /* 0  bLength */
           USB_DESCTYPE_CS_INTERFACE, /* 1  bDescriptortype, CS_INTERFACE */
           0x02,                      /* 2  bDescriptorsubtype, ABSTRACT CONTROL MANAGEMENT */
           0x02,                      /* 3  bmCapabilities: Supports subset of ACM commands */

           /* Union Functional descriptor */
/*18*/     0x05,                     /* 0  bLength */
           USB_DESCTYPE_CS_INTERFACE,/* 1  bDescriptortype, CS_INTERFACE */
           0x06,                     /* 2  bDescriptorsubtype, UNION */
           UPDATE,                   /* 3  bControlInterface - Interface 2 */  //!!UPDATE@21!!
           UPDATE,                   /* 4  bSubordinateInterface0 - Interface 3 */ //!!UPDATE@22!!

           /* Call Management Functional descriptor */
/*23*/     0x05,                     /* 0  bLength */
           USB_DESCTYPE_CS_INTERFACE,/* 1  bDescriptortype, CS_INTERFACE */
           0x01,                     /* 2  bDescriptorsubtype, CALL MANAGEMENT */
           0x03,                     /* 3  bmCapabilities, DIY */
           0x03,                     /* 4  bDataInterface */

           /* Notification Endpoint descriptor */
/*28*/     0x07,                         /* 0  bLength */
           USB_DESCTYPE_ENDPOINT,        /* 1  bDescriptorType */
           UPDATE,                       /* 2  bEndpointAddress */ //!!UPDATE@30!!
           0x03,                         /* 3  bmAttributes */
           0x40,                         /* 4  wMaxPacketSize - Low */
           0x00,                         /* 5  wMaxPacketSize - High */
           0xFF,                         /* 6  bInterval */

           /* CDC Data interface */
/*35*/     0x09,                     /* 0  bLength */
           USB_DESCTYPE_INTERFACE,   /* 1  bDescriptorType */
           UPDATE,                   /* 2  bInterfacecNumber */ //!!UPDATE@37!!
           0x00,                     /* 3  bAlternateSetting */
           0x02,                     /* 4  bNumEndpoints */
           USB_CLASS_CDC_DATA,       /* 5  bInterfaceClass */
           0x00,                     /* 6  bInterfaceSubClass */
           0x00,                     /* 7  bInterfaceProtocol*/
           0x00,                     /* 8  iInterface - No string descriptor*/

           /* Data OUT Endpoint descriptor */
/*43*/     0x07,                     /* 0  bLength */
           USB_DESCTYPE_ENDPOINT,    /* 1  bDescriptorType */
           UPDATE,                   /* 2  bEndpointAddress */ //!!UPDATE@45!!
           0x02,                     /* 3  bmAttributes */
           0x00,                     /* 4  wMaxPacketSize - Low */
           0x02,                     /* 5  wMaxPacketSize - High */
           0x00,                     /* 6  bInterval */

           /* Data IN Endpoint descriptor */
/*50*/     0x07,                     /* 0  bLength */
           USB_DESCTYPE_ENDPOINT,    /* 1  bDescriptorType */
           UPDATE,                   /* 2  bEndpointAddress */ //!!UPDATE@52!!
           0x02,          /* 3  bmAttributes */
           0x00,                     /* 4  wMaxPacketSize - Low byte */
           0x02,                     /* 5  wMaxPacketSize - High byte */
           0x01                      /* 6  bInterval */
};


/* Device Descriptor */
static unsigned char devDesc[] =
{
    0x12,                     /* 0  bLength */
    USB_DESCTYPE_DEVICE,      /* 1  bdescriptorType */
    0x00,                     /* 2  bcdUSB */
    0x02,                     /* 3  bcdUSB */
    VENDOR_SPECIFIC_CLASS,    /* 4  bDeviceClass */
    VENDOR_SPECIFIC_SUBCLASS, /* 5  bDeviceSubClass */
    VENDOR_SPECIFIC_PROTOCOL, /* 6  bDeviceProtocol */
    0x40,                     /* 7  bMaxPacketSize */
    (VENDOR_ID & 0xFF),       /* 8  idVendor */
    (VENDOR_ID >> 8),         /* 9  idVendor */
    (PRODUCT_ID & 0xFF),      /* 10 idProduct */
    (PRODUCT_ID >> 8),        /* 11 idProduct */
    (BCD_DEVICE & 0xFF),      /* 12 bcdDevice */
    (BCD_DEVICE >> 8),        /* 13 bcdDevice */
    MANUFACTURER_STR_INDEX,   /* 14 iManufacturer */
    PRODUCT_STR_INDEX,        /* 15 iProduct */
    0x00,                     /* 16 iSerialNumber */
    0x01                      /* 17 bNumConfigurations */
};


#if 0
static unsigned char cfgDesc[9 + N_CDC*(sizeof(IAD) + sizeof(CDC))]={

        0x09,                       /* 0  bLength */
        USB_DESCTYPE_CONFIGURATION, /* 1  bDescriptortype - Configuration*/
        CFG_LEN, 0x00,                 /* 2  wTotalLength */
        0x04,                       /* 4  bNumInterfaces */
        0x01,                       /* 5  bConfigurationValue */
        0x00,                       /* 6  iConfiguration - index of string */
        0x80,                       /* 7  bmAttributes - Bus powered */
        0xC8,                       /* 8  bMaxPower - 400mA */
};
#endif

static unsigned char MSOS20PlatformCapabilityDescriptor[] =
{
    //
    // Microsoft OS 2.0 Platform Capability Descriptor Header
    //
    0x1C,                    // bLength - 28 bytes
    0x10,                    // bDescriptorType - 16
    0x05,                    // bDevCapability – 5 for Platform Capability
    0x00,                    // bReserved - 0
    0xDF, 0x60, 0xDD, 0xD8,  // MS_OS_20_Platform_Capability_ID -
    0x89, 0x45, 0xC7, 0x4C,  // {D8DD60DF-4589-4CC7-9CD2-659D9E648A9F}
    0x9C, 0xD2, 0x65, 0x9D,  //
    0x9E, 0x64, 0x8A, 0x9F,  //

    //
    // Descriptor Information Set for Windows 8.1 or later
    //
    0x00, 0x00, 0x03, 0x06,  // dwWindowsVersion – 0x06030000 for Windows Blue
    0x48, 0x00,              // wLength – size of MS OS 2.0 descriptor set
    0x01,                    // bMS_VendorCode
    0x00,                    // bAltEnumCmd – 0 Does not support alternate enum
};


#define USB_Isochronous 0b01 // async see https://www.beyondlogic.org/usbnutshell/usb5.shtml#EndpointDescriptors

static unsigned char cfgBulkDesc[]=
{
    0x09,                     /* 0  bLength */
    0x04,                     /* 1  bDescriptorType */
    0x00,                     /* 2  bInterfacecNumber */
    0x00,                     /* 3  bAlternateSetting */
    0x02,                     /* 4: bNumEndpoints */
    0xFF,                     /* 5: bInterfaceClass */
    0xFF,                     /* 6: bInterfaceSubClass */
    0xFF,                     /* 7: bInterfaceProtocol*/
    0x03,                     /* 8  iInterface */

    0x07,                     /* 0  bLength */
    0x05,                     /* 1  bDescriptorType */
    0x01,                     /* 2  bEndpointAddress */  //EP1
    0x02,                     /* 3  bmAttributes */
    0x00,                     /* 4  wMaxPacketSize */
    0x02,                     /* 5  wMaxPacketSize */
    0x01,                     /* 6  bInterval */

    0x07,                     /* 0  bLength */
    0x05,                     /* 1  bDescriptorType */
    0x81,                     /* 2  bEndpointAddress */  //EP1
    0x02,                     /* 3  bmAttributes */ //BULK MODE see https://www.beyondlogic.org/usbnutshell/usb5.shtml#EndpointDescriptors
    PKG_SIZE & 0xFF,          /* 4  wMaxPacketSize */
    PKG_SIZE>>8,              /* 5  wMaxPacketSize */
    0x01                      /* 6  bInterval */ //must be 1 for ISO
};

#define cfgDescHeadSize 9
#if(N_CDC == 0)
#define sizeof_cfgDesc (cfgDescHeadSize + sizeof( cfgBulkDesc))
#else
#define sizeof_cfgDesc (cfgDescHeadSize + sizeof( cfgBulkDesc) + N_CDC*(sizeof(IAD_CDC) + sizeof(CDC)))

#endif
    /* Configuration Descriptor */
static unsigned char cfgDesc[sizeof_cfgDesc] =
{
    cfgDescHeadSize,           /* 0  bLength */
    USB_DESCTYPE_CONFIGURATION,/* 1  bDescriptortype */
    sizeof_cfgDesc & 0xFF,
    sizeof_cfgDesc>>8,        /* 2  wTotalLength */
    0x01+ 2*N_CDC,            /* 4  bNumInterfaces */
    0x01,                     /* 5  bConfigurationValue */
    0x00,                     /* 6  iConfiguration */
    0x80,                     /* 7  bmAttributes */
    0xFA                      /* 8  bMaxPower */
};



/* Set language string to US English */
#define STR_USENG 0x0409

/* String table */
unsafe
{
    static char * unsafe stringDescriptors[] =
    {
            "\x09\x04",                             // Language ID string (US English)
            "XMOS",                                 // iManufacturer
            "XMOS BLDC motor driver",     // iProduct
            "Custom Interface",                     // iInterface
            "Config",                               // iConfiguration
    };
}




#endif /* DESCRIPTORS_H_ */
