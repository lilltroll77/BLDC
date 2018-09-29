/*
 * ports.h
 *
 *  Created on: 23 sep 2018
 *      Author: Mikael Bohman
 */


#ifndef PORTS_H_
#define PORTS_H_


//Ports
on tile[0]:struct p_t DS={XS1_PORT_1M , XS1_PORT_1P , XS1_PORT_1G , XS1_PORT_1N , XS1_PORT_1O , XS1_PORT_1H ,XS1_CLKBLK_3};
on tile[0]:in port p_button = XS1_PORT_4E;
on tile[0]:out port p_svpwm = XS1_PORT_8B;
on tile[0]:in port p_fault = XS1_PORT_1L;
on tile[0]:clock clk_pwm =  XS1_CLKBLK_2;
on tile[0]:SPI_t spi_r={XS1_PORT_1J , XS1_PORT_1K , XS1_PORT_1I , XS1_PORT_4F ,  XS1_CLKBLK_1};
on tile[1]:QE_t QE_r={XS1_PORT_1L , XS1_PORT_1O , XS1_PORT_1P};
on tile[0]:port p_SCL = XS1_PORT_1E;


#endif /* PORTS_H_ */
