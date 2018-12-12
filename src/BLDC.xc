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
#include "usb_server.h"
#include "gui_server.h"
#include "svm.h"
#include "ports.h"
#include "FOC.h"


extern void QE(streaming chanend c_out , in port pA , in port pB , in port pX , unsigned QEangle[1]);
extern void decimate64(streaming chanend c , in buffered port:32 p);
extern void wait(unsigned clk);


int main(){
    streaming chan c_Idata[2], c_QE, c_FOC,c_svm;
    interface GUI_supervisor_interface supervisor_data;
    streaming chan sc_GUI2RX , sc_FOC2CDC , sc_FOC2GUI;

    par{
      on tile[1]:{
          unsigned QEangle[1];
          unsafe{
          unsigned* unsafe angle = QEangle;
          par{
              usb_server( sc_FOC2CDC , sc_GUI2RX , angle );
              QE(c_QE , QE_r.A , QE_r.B , QE_r.X , QEangle);
          }}
      }

        //on tile[0]:  microFIFO(c_FIFO);
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
            unsafe{
                par{
                decimate64(c_Idata[0] , DS.DATA_A);
                decimate64(c_Idata[1] , DS.DATA_C);
                FOC(c_Idata , c_QE ,c_FOC , sc_FOC2GUI , sc_FOC2CDC);
                SVM( c_FOC , c_svm );
                svpwm(c_svm , clk_pwm  ,p_svpwm );
                supervisor_cores(supervisor_data , p_button , p_fault , spi_r , p_SCL);
                gui_server(sc_GUI2RX , sc_FOC2GUI);
             }}


            } // tile[0]



    } // par
    return 0;
}
