
#include "endpoints.h"
#include "string.h"
#include "descriptors.h"
#include "stdio.h"
#include "usb_server.h"

#define DEBUG 0


//Only work for CDC class
unsafe unsigned char* unsafe writeIAD(unsigned char* unsafe ptr , unsigned char intf){
    memcpy(ptr , IAD_CDC , sizeof(IAD_CDC));
    ptr[2]=intf; //bFirstInterface
    return ptr+sizeof(IAD_CDC);
}

unsafe unsigned char* unsafe writeCDC(unsigned char* unsafe ptr , struct descriptor_t cdc){
    memcpy(ptr , CDC , sizeof(CDC));
    ptr[2]= cdc.intf.notification;
    ptr[21]=cdc.intf.notification;
    ptr[22]=cdc.intf.data;
    ptr[30]=cdc.EP.notification;
    ptr[37]=cdc.intf.data;
    ptr[45]=cdc.EP.rx;
    ptr[52]=cdc.EP.tx | 0x80;
    return ptr+sizeof(CDC);

}


unsafe void Endpoints(server interface cdc_if cdc[] , chanend chan_ep_out[] , XUD_buffers_t &buffer)
{
    set_core_high_priority_off();
    struct descriptor_t cdc_desc;

    unsafe{
        unsigned char* unsafe ptr = &cfgDesc[cfgDescHeadSize];
#if(N_CDC>0)
        // memcpy(ptr , IAD_BULK , sizeof(IAD_BULK));
        // ptr += sizeof(IAD_BULK);
         devDesc[4] = 0xEF;  /* 4  bDeviceClass - USB Class for IAD*/
         devDesc[5] = 0x02;  /* 5  bDeviceSubClass*/
         devDesc[6] = 0x01;
#endif
        memcpy( ptr , cfgBulkDesc , sizeof(cfgBulkDesc)); //Interface 0
        ptr += sizeof(cfgBulkDesc);

        const int offset=1;
        for(int i=0; i<N_CDC ; i++){
            int i2=2*i;
            cdc_desc.intf.notification=  i2+  offset; //Interface 1,3,5
            cdc_desc.intf.data =         i2+1+offset; //Interface 2,4,6
            cdc_desc.EP.notification =   i2+1+offset; //EP 2,4,6,8
            cdc_desc.EP.rx =             i+1+ offset; //EP 2,3,4,5,6
            cdc_desc.EP.tx =             i2+2+offset; //EP 3,5,7,9
            ptr = writeIAD(ptr , cdc_desc.intf.notification); // ( 1,3,5,7) //First interface
            ptr = writeCDC(ptr , cdc_desc);
        }
    }

    USB_SetupPacket_t sp;
    XUD_BusSpeed_t usbBusSpeed;
    buffer.reset_N =1;

    unsigned char sbuffer[120]={0};
    unsigned length;
    XUD_Result_t result;
    XUD_SetReady_Out(buffer.rx.ep[0] , sbuffer);

    XUD_SetReady_Out(buffer.rx.ep[1], (char*) buffer.rx.fifo1);
#if(N_CDC>0)
    XUD_SetReady_Out(buffer.rx.ep[2], (char*) buffer.rx.fifo2);
#endif
//XUD_SetReady_Out(buffer.rx.ep[2], (buffer.rx.fifo2 , unsigned char []));

    buffer.rx.pkg_maxSize1=64;


    //safememcpy(&devDesc[0xEE] , MSOS20PlatformCapabilityDescriptor , sizeof(MSOS20PlatformCapabilityDescriptor));
    //devDesc[0] = sizeof(devDesc);

    while(1){
        select{
          // XUD_GetSetupData (chanend c, XUD_ep ep, REFERENCE_PARAM(unsigned, length), REFERENCE_PARAM(XUD_Result_t, result));
        case XUD_GetSetupData_Select( chan_ep_out[0] , buffer.rx.ep[0] , length , result):
                USB_ParseSetupPacket(sbuffer, sp); // Data in sbuffer
        if(result== XUD_RES_OKAY){
             // printf("SetupData OK\n");
              /* Set result to ERR, we expect it to get set to OKAY if a request is handled */
              result = XUD_RES_ERR;
              /* Stick bmRequest type back together for an easier parse... */
#if N_CDC>0
              unsigned bmRequestType = (sp.bmRequestType.Direction<<7) |
                      (sp.bmRequestType.Type<<5) |
                      (sp.bmRequestType.Recipient);
              if ((bmRequestType == USB_BMREQ_H2D_STANDARD_DEV) &&
                      (sp.bRequest == USB_SET_ADDRESS))
              {  /* Host has set device address, value contained in sp.wValue*/
                 printf("set device address:%d\n",sp.wValue);
              }
              /* Inspect for CDC Communications Class interface num */
              if(sp.wIndex == 0){

                  switch(bmRequestType)
                  {
                  /* Direction: Device-to-host and Host-to-device
                   * Type: Class
                   * Recipient: Interface
                   */
                  case USB_BMREQ_H2D_CLASS_INT:
                  case USB_BMREQ_D2H_CLASS_INT:

                      /* Returns  XUD_RES_OKAY if handled,
                       *          XUD_RES_ERR if not handled,
                       *          XUD_RES_RST for bus reset */
                      result = ControlInterfaceClassRequests(buffer.rx.ep[0], buffer.tx.ep[0], sp);
                      printf("ControlInterfaceClassRequests=%d" , result);
                  break;
                  default:
                      //printf("WARNING: Unknown bmRequestType:%d , MASK:0x%x bRequest:%d\n" , bmRequestType , USB_BMREQ_D2H_CLASS_INT ,sp.bRequest);
                      break;
                  }
              }//if
              //else
               // printf("wTindex=0x%x\n",sp.wIndex);

#endif
              //break;
        }
        if(result == XUD_RES_ERR){
             printf("USB_StandardRequests for enumeration\n");
             result = USB_StandardRequests(buffer.rx.ep[0], buffer.tx.ep[0], devDesc,
                     sizeof(devDesc), cfgDesc, sizeof(cfgDesc),
                     null, 0,
                     null, 0,
                     stringDescriptors, sizeof(stringDescriptors)/sizeof(stringDescriptors[0]),
                     sp, usbBusSpeed);
        }
        if(result==XUD_RES_RST)
            usbBusSpeed = XUD_ResetEndpoint(buffer.rx.ep[0], buffer.tx.ep[0]);

        memset(sbuffer , 0 , sizeof(sbuffer));
        XUD_SetReady_Out(buffer.rx.ep[0] , sbuffer);

        //switch
        //XUD_SetReady_Out(buffer.rx.ep[0] , sbuffer);

        break;
// Get DATA
          case XUD_GetData_Select(chan_ep_out[1],  buffer.rx.ep[1] , length ,result):

#if(DEBUG == 1)
        printf("EP: GetData, len=%d result = %d\n" , length , result);
#endif
        if(result == XUD_RES_RST){
            result = XUD_ResetEndpoint(buffer.rx.ep[1] , null);
            // //block Set data reset
            resetPointers(buffer);
            XUD_SetReady_Out(buffer.rx.ep[1], (char*) buffer.rx.write1);
#if(DEBUG_RESET)
            printf("EP: !! RESET!! in GETDATA, res=%d" , result);
#endif
            break;
        }
        if(result == XUD_RES_ERR)
            printf("EP: !! error!! in GETDATA");
        else if(result == XUD_RES_OKAY){
            buffer.rx.queue_len1++;
            cdc[0].data_available();
#if(DEBUG == 1)
            printf("cdc[0].data_available()\n");
#endif
           //*write+= length;                // move write pointer !! length is in bytes !!
            buffer.rx.write1 +=length /=sizeof(int);

          //reseting RX write
            if( buffer.rx.write1 >= buffer.rx.fifo2 - buffer.rx.pkg_maxSize1){ //does it risk to start writing into fifo2?
             buffer.rx.fifoLen1 = buffer.rx.write1; //update actual FIFO len that has data
             buffer.rx.write1 = buffer.rx.fifo1;
             printf("CDC: Reset RX write pos\n");
         }
#if(DEBUG == 1)
           printf("EP: WritePos=%d\n" , buffer.rx.write1);
#endif
        }
        // add to queue
         XUD_SetReady_Out(buffer.rx.ep[1] , (char*) buffer.rx.write1 );
        break;
        case cdc->queue_empty():
         break;
// DEFAULT
#if(0)
        default:
            if( buffer.tx.read1 != buffer.tx.write1){
                XUD_SetReady_In(  buffer.tx.ep[1] , (char*) buffer.tx.read1 , 4);
#if(DEBUG == 1)
                printf("TX package qeueud: %f , %f , read=%d write=%d\n" , (*buffer.tx.read1,float), (float) *buffer.tx.write1 , buffer.tx.read1 - buffer.tx.fifo1 , buffer.tx.write1- buffer.tx.fifo1);
#endif
                buffer.tx.read1++;
                //RESETTING TX Read ptr
                if(buffer.tx.read1 == buffer.tx.fifo2){  //pointer has reached next buffer
                    buffer.tx.read1 = buffer.tx.fifo1;    // reset to beginning of buffer
#if(DEBUG)
                    printf("CDC: Reset TX read pos\n");
#endif
                }
            }
                break;
#endif


        }
    }
}
