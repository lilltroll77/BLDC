/*
 * BLDC.xc
 *
 *  Created on: 11 sep 2018
 *      Author: Mikael Bohman
 */

#include <platform.h>
#include <xs1.h>
#include <xclib.h>
#include "print.h"
#include <xscope.h>
#include "typedefs.h"
#include "supervisor.h"
#include "usb.h"
#include "xud_cdc.h"



//#include "math.h"


//#include "app_virtual_com_extended.h"
#include "svm.h"
#include "ports.h"


/* USB Endpoint Defines */
#define XUD_EP_COUNT_OUT   3    //Includes EP0 (1 OUT EP0 + 1 BULK OUT EP)
#define XUD_EP_COUNT_IN    5    //Includes EP0 (1 IN EP0 + 1 INTERRUPT IN EP + 1 BULK IN EP)
#define USB_TILE tile[1]



extern void QE(streaming chanend c_out , in port pA , in port pB , in port pX);
extern void FOC(streaming chanend c_I[2] , streaming chanend c_fi , streaming chanend c_out, streaming chanend c_FIFO);
extern void decimate64(streaming chanend c , in buffered port:32 p);
extern void wait(unsigned clk);


void rawdata(streaming chanend c , in buffered port:32 p){
    wait(1e5);
    unsigned val;
    while(1){
        p :> val;
        c<: bitrev(val);
    }
}

void control(streaming chanend c_in , streaming chanend c_out , streaming chanend c_QE){
    int x,y,angle;
    int acc=0;
    int set=135000+1000;
    while(1){
        select{
        case c_QE :> angle:
            break;
        case c_in :> x:
            y= (set-x)>>3;
            acc +=y>>5;
            y +=acc;
            if(y<50)
                y=50;
            else if(y>(Tp-50))
                y=(Tp-50);
            c_out <:y;
            //xscope_int(ANGLE,y);
            break;
        }
    }
}

void microFIFO(streaming chanend c){
    set_core_high_priority_off();
    int val1,val2;
    while(1){
        c:> val1;
        xscope_int(I_D, val1);
        c:> val2;
        xscope_int(I_Q, val2);
    }
}

int main(){
    streaming chan c_Idata[2], c_pwm , c_QE, c_FOC;
    streaming chan c_svm, c_FIFO;
    chan c_ep_out[XUD_EP_COUNT_OUT], c_ep_in[XUD_EP_COUNT_IN];
    interface usb_cdc_interface cdc_data[2];
    interface GUI_supervisor_interface supervisor_data;

    par{

        on USB_TILE: xud(c_ep_out, XUD_EP_COUNT_OUT, c_ep_in, XUD_EP_COUNT_IN,
                null, XUD_SPEED_HS, XUD_PWR_SELF);
        on USB_TILE: Endpoint0(c_ep_out[0], c_ep_in[0]);
        on USB_TILE: CdcEndpointsHandler(c_ep_in[CDC_NOTIFICATION_EP_NUM1], c_ep_out[CDC_DATA_RX_EP_NUM1], c_ep_in[CDC_DATA_TX_EP_NUM1], cdc_data[0]);
        on USB_TILE: CdcEndpointsHandler(c_ep_in[CDC_NOTIFICATION_EP_NUM2], c_ep_out[CDC_DATA_RX_EP_NUM2], c_ep_in[CDC_DATA_TX_EP_NUM2], cdc_data[1]);
        on USB_TILE: [[combine]] par{
                     GUIhandler(cdc_data[0] , supervisor_data);
                     GCODEhandler(cdc_data[1]);
        }
        //on USB_TILE: app_virtual_com_extended(cdc_data[1]);

        on tile[1]:  QE(c_QE , QE_r.A , QE_r.B , QE_r.X);
        on tile[0]:  microFIFO(c_FIFO);
        on tile[0]:{

            set_clock_div(spi_r.clkblk , 500); // 1MHz
            set_clock_xcore(clk_pwm);

            //ADC ports
            set_clock_xcore(DS.clkBLOCK);
            set_clock_div(DS.clkBLOCK , CLKDIV);
            configure_port_clock_output(DS.clk_A ,DS.clkBLOCK);
            configure_port_clock_output(DS.clk_C ,DS.clkBLOCK);
            configure_in_port(DS.DATA_A , DS.clkBLOCK);
            configure_in_port(DS.DATA_C , DS.clkBLOCK);
            start_clock(DS.clkBLOCK);

            // SPI ports
            configure_in_port(spi_r.MISO , spi_r.clkblk );
            configure_out_port(spi_r.MOSI , spi_r.clkblk , 0);
            configure_out_port(spi_r.CLK , spi_r.clkblk , 0);
            configure_out_port(p_svpwm ,clk_pwm ,0 );

            init_TIdriver(spi_r);

            par{
                decimate64(c_Idata[0] , DS.DATA_A);
                decimate64(c_Idata[1] , DS.DATA_C);
                FOC(c_Idata , c_QE ,c_FOC , c_FIFO);
                SVM( c_FOC , c_svm );
                svpwm(c_svm , clk_pwm  ,p_svpwm );
                supervisor_cores(supervisor_data , p_button , p_fault , spi_r , p_SCL);

                }

            } // tile[0]



    } // par
    return 0;
}
