/*
 * spi.h
 *
 *  Created on: 23 sep 2018
 *      Author: Mikael Bohman
 */


#ifndef SPI_H_
#define SPI_H_

#include "xud_cdc.h"

void WriteToDRV8320S(unsigned addr , unsigned data , SPI_t &spi_r);
unsigned ReadFromDRV8320S(unsigned addr , SPI_t &spi_r);
void supervisor_cores(server interface GUI_supervisor_interface supervisor_data  , in port p_button , in port p_fault , SPI_t &spi_r , port p_temp);
void init_TIdriver( SPI_t &spi_r);


#endif

/* SPI_H_ */
