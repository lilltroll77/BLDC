/*
 * spi.h
 *
 *  Created on: 23 sep 2018
 *      Author: Mikael Bohman
 */


#ifndef SPI_H_
#define SPI_H_

#include "xud_cdc.h"
#include "typedefs.h"

#define CT_NOTIFICATION 5 //Control token

enum message_enum{SHUTDOWN=1 , DRV_ERROR=2 , TEMP_CHANGED=4 , OVER_CURRENT=8};
enum ctrl_TI_enum{reset_TI , reset_error_TI , write_TI , writeReturn_TI ,disable_TI ,enable_TI};


void setCtrlPort(SPI_t &spi_r , enum ctrl_TI_enum command);
void WriteToDRV8320S(unsigned addr , unsigned data , SPI_t &spi_r);
unsigned ReadFromDRV8320S(unsigned addr , SPI_t &spi_r);
unsafe void supervisor_cores(server interface GUI_supervisor_interface supervisor_data  , streaming chanend c_FOC, streaming chanend c_Dec16 ,in port p_button , in port p_fault , SPI_t &spi_r , port p_temp, current_t *unsafe I);
void init_TIdriver( SPI_t &spi_r);


#endif

/* SPI_H_ */
