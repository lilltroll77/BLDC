/*
 * cdc_handlers.xc
 *
 *  Created on: 27 okt 2018
 *      Author: micke
 */

#include <stdio.h>
#include "print.h"
#include <math.h>
#include "cdc_handlers.h"
#include "RX_block.h"
#include "calc.h"

#define DEBUG 0

//cdc data is queued on a FIFO
unsafe void cdc_handler1(client interface cdc_if cdc , client interface GUI_supervisor_interface supervisor  , streaming chanend c_from_FOC , streaming chanend c_from_RX, chanend c_ep_in[],XUD_buffers_t * unsafe buff){
    set_core_high_priority_off();
    XUD_Result_t result;
    int buffer_writing2host=InEPready;
    char* unsafe writePtr;
    struct USBmem_t* unsafe USBmem;
    struct regulator_t* unsafe reg;
    struct state_t* unsafe dsp_state;
    c_from_RX :> USBmem;
    c_from_FOC :> reg;
    c_from_FOC :> dsp_state;
     //printf("CDCin %d" , reg);
    //printintln(val);
    while(1){
        select{
        case supervisor.notification():
            unsigned info = supervisor.getInfo();
            USBmem[0].changed ^= info;
            if(info &DRV_ERROR){ // Send error status reg to GUI
                 for(int i=0; i <2 ; i++)
                    USBmem[0].GateDrvStatus[i] = supervisor.readGateDriver(i);
            }
            if(info &DRV_SETTINGS){ // Send error status reg to GUI
                for(int i=2; i <6 ; i++)
                    USBmem[0].GateDrvStatus[i] = supervisor.readGateDriver(i);
            }
            if( info &TEMP_CHANGED ){
                USBmem[0].temp = supervisor.readTemperature(0);

            }

            break;
        case c_from_RX :> writePtr:
           if( buffer_writing2host == InEPready){
                XUD_SetReady_In(buff->tx.ep[1] ,(char*) writePtr , PKG_SIZE );
#if(0)
           if(first){
              struct USBmem_t* unsafe mem=(struct USBmem_t* unsafe)writePtr;
                for(int i=0;i<4;i++)
                    printintln( mem->fast.IA[i]);
                first--;
                }
#endif
                writePtr +=PKG_SIZE;
                buffer_writing2host = 1;
            }
            else
                buffer_writing2host = BufferReadyToWrite; // Redundat ??
        break;
        case cdc.data_available():
            //printf("cdc.data_available");
            while(buff->rx.queue_len1 > 0){
#if(DEBUG == 1)
                printf("CDC commad:%d" , *buff->rx.read1);

#endif
                switch(*buff->rx.read1++){
                 case streamOUT:
                    int state = *buff->rx.read1++;
                    soutct(c_from_RX , 0); // Reset all states in RX
                    if(state)
                        printf("stream out: ON\n");
                    else
                        printf("stream out: OFF\n");
                    c_from_FOC <: streamOUT;
                    c_from_FOC <: state; //Tell dsp core to start/stop sending sync signals

                break;
                 case PIsection:{
                     int ch = buff->rx.read1[0];
                     void* unsafe ptr = &reg[ch];
                     //printf("CDC PI %d\n" , reg);
                    // struct PI_t* pi = &reg[ch];
                     {
                         c_from_FOC  <: PIsection;
                         c_from_FOC  <: ptr;
                         c_from_FOC  <: buff->rx.read1[3];
                         c_from_FOC  <: buff->rx.read1[4];
                     }
                     buff->rx.read1 += 5;
                 }
                     break;
                 case EQsection:{
                     //see struct USB_EQsection_t in QT usbbulk.h
                     int i;
                     int ch =  buff->rx.read1[0];
                     int sec = buff->rx.read1[1];
                     int section = 2*ch +sec;
                     int active = buff->rx.read1[3];
                     void* unsafe ptr = &reg[ch].EQ[sec];
                     //printf("CDC EQ %d\n" , reg);
                    c_from_FOC <: EQsection;
                     c_from_FOC <:  ptr;
#pragma loop unroll
                     {

                         for(i=8 ; i< 11 ; i++)
                             c_from_FOC <: buff->rx.read1[i];  //B coeffs
                         for(i ; i< 13 ; i++)
                             c_from_FOC <: -buff->rx.read1[i]; //Invert A coeffs
                     }
                     if(active)
                         c_from_FOC <: buff->rx.read1[i]; //shift
                     else{
                         c_from_FOC <: -1; //Bypass section...
                         c_from_FOC <: resetEQsec;
                         c_from_FOC <: &dsp_state[section];//... and reset states

                     }
                     buff->rx.read1 +=i+1;
                     }
                     break;
                 case resetPI:
                     c_from_FOC <:resetPI;
                     c_from_FOC <:buff->rx.read1[0];
                     buff->rx.read1++;
                     break;
                 case resetEQ:
                     unsafe{
                         for(int i=0; i<4 ; i++){
                             c_from_FOC <: resetEQsec;
                             c_from_FOC <: &dsp_state[i];
                         }
                     }
                     break;
                 case FuseCurrent:
                     const float gain = 16384.0f; // for testing
                     int current = gain*(buff->rx.read1[0] , float);
                     buff->rx.read1++;
                     soutct(c_from_RX , fuse_SETCURRENT);
                     c_from_RX <: current;

                     break;
                 case NewFuse:
                     //Reset all states
                     unsafe{
                         for(int i=0; i<4 ; i++){
                             c_from_FOC <: resetEQsec;
                             c_from_FOC <: &dsp_state[i];

                         }
                         c_from_FOC <:resetPI;
                         c_from_FOC <:0;
                         c_from_FOC <:resetPI;
                         c_from_FOC <:1;
                     }
                     soutct(c_from_RX , fuse_GOOD);

                     break;
                 case SignalSource:
                     //c_from_FOC <: SignalSource;
                     //c_from_FOC <: buff->rx.read1[0];
                     buff->rx.read1++;
                     break;
                 case SignalGenerator:
                     //printint(buff->rx.read1[0]);
                     //c_fromSigGen <: buff->rx.read1[0];
                     buff->rx.read1++;
                     break;
                 case DRV_VDS:
                     int data_val = *buff->rx.read1++;
                     short reg_data=supervisor.readGateDriver(VDS_REG);
                     reg_data &=0xFF0;
                     reg_data |=data_val;
                     supervisor.writeGateDriver(VDS_REG , reg_data);
                     printstr("COM VDS: ");
                     printhex(data_val);printchar(',');printhexln(reg_data);
                     break;
                 case DRV_ODT:
                     int data_val = *buff->rx.read1++;
                     short reg_data=supervisor.readGateDriver(ODT_REG);
                     reg_data &=0x4FF;
                     reg_data |=data_val<<8;
                     supervisor.writeGateDriver(ODT_REG , reg_data);
                     printstr("COM ODT:");
                     printhex(data_val);printchar(',');printhexln(reg_data);
                     break;
                 case DRV_TDRIVE:
                     int data_val = *buff->rx.read1++;
                     short reg_data=supervisor.readGateDriver(TDRIVE_REG);
                     reg_data &=0x4FF;
                     reg_data |=data_val<<8;
                     supervisor.writeGateDriver(TDRIVE_REG , reg_data);
                     printstr("COM TDRIVE:");
                     printhex(data_val);printchar(',');printhexln(reg_data);
                     break;
                 case DRV_IDRIVE_P_HS:
                     int data_val = *buff->rx.read1++;
                     short reg_data=supervisor.readGateDriver(HISIDE_REG);
                     reg_data &=0xF0F;
                     reg_data |=data_val<<4;
                     supervisor.writeGateDriver(HISIDE_REG , reg_data);
                     printstr("COM IDRIVE: P-HS ");
                     printhex(data_val);printchar(',');printhexln(reg_data);;
                     break;
                 case DRV_IDRIVE_N_HS:
                     int data_val = *buff->rx.read1++;
                     short reg_data=supervisor.readGateDriver(HISIDE_REG);
                     reg_data &=0xFF0;
                     reg_data |=data_val;
                     supervisor.writeGateDriver(HISIDE_REG , reg_data);
                     printstr("COM IDRIVE: N-HS ");
                     printhex(data_val);printchar(',');printhexln(reg_data);
                     break;
                 case DRV_IDRIVE_P_LS:
                     int data_val = *buff->rx.read1++;
                     short reg_data=supervisor.readGateDriver(LOSIDE_REG);
                     reg_data &=0xF0F;
                     reg_data |=data_val<<4;
                     supervisor.writeGateDriver(LOSIDE_REG, reg_data);
                     printstr("COM IDRIVE: P-LS ");
                     printhex(data_val);printchar(',');printhexln(reg_data);
                     break;
                 case DRV_IDRIVE_N_LS:
                     int data_val = *buff->rx.read1++;
                     short reg_data=supervisor.readGateDriver(LOSIDE_REG);
                     reg_data &=0xFF0;
                     reg_data |=data_val;
                     supervisor.writeGateDriver(LOSIDE_REG , reg_data);
                     printstr("COM IDRIVE: N-LS ");
                     printhex(data_val);printchar(',');printhexln(reg_data);
                     break;
                 case DRV_RESET:
                     int data_val = *buff->rx.read1++;
                     supervisor.resetGateDriver();
                     //printstr("GATE-DRV RESET");
                     break;
                default:
                    printf("Unknown command %d %d %d\n" , buff->rx.read1[0] , buff->rx.read1[1],buff->rx.read1[2]);
                    break;
                }


#if(DEBUG)
                    printf("CDC: Reset RX write pos\n");
#endif


                if(buff->rx.read1 >= buff->rx.fifoLen1){  //Passed last written place in FIFO
                    buff->rx.read1 = buff->rx.fifo1;      //reset to start of FIFO1

#if(DEBUG)
                    printf("CDC: Reset read RX pos\n");
#endif
                    }

                buff->rx.queue_len1--;
            }
            cdc.queue_empty();
            break;
            case XUD_SetData_Select(c_ep_in[1],  buff->tx.ep[1] , result):
                if(result == XUD_RES_RST){
                    result = XUD_ResetEndpoint(buff->tx.ep[1] , null);
#if(DEBUG_RESET)
                    printf("CDC: !! RESET!! in SETDATA result = %d\n" , result);
#endif               //XUD_SetReady_In(   buff->tx.ep[1] , (char*) buff->tx.fifo1 ,0);
                break;
                }
                if(result == XUD_RES_ERR){
                    printf("CDC: !! RES_ERROR!! in SETDATA");
                    break;
                }
                if(buffer_writing2host >= BufferReadyToWrite){
                    XUD_SetReady_In(buff->tx.ep[1] ,(char*) writePtr , PKG_SIZE );
                    writePtr +=PKG_SIZE;
                    buffer_writing2host++;
                    if(buffer_writing2host >= 8)
                        buffer_writing2host = InEPready;
                    break;
                }
                buffer_writing2host = InEPready;
              break;
#if N_CDC>0
            case XUD_SetData_Select(c_ep_in[3],  buff->tx.ep[3] , result):
#endif
                    break;
        }//select
    }
}



