/*
 * spi.h
 *
 *  Created on: 23 sep 2018
 *      Author: Mikael Bohman
 */


#ifndef SPI_H_
#define SPI_H_

#include "typedefs.h"

enum message{SHUTDOWN=1 , DRV_ERROR=2 , TEMP_CHANGED=4 , OVER_CURRENT=8};

interface GUI_supervisor_interface{
    [[notification]] slave void data_waiting( void );
    [[clears_notification]] [[guarded]] int getInfo(void);
    [[guarded]] short readTemperature(char ID);
    [[guarded]] short readGateDriver(char reg);
    [[guarded]] int writeGateDriver(char reg , short data);
    [[guarded]] int resetGateDriver();
    [[guarded]] unsigned readCurrent(int reset);
    [[guarded]] void setMaxCurrent(unsigned current);
};

void WriteToDRV8320S(unsigned addr , unsigned data , SPI_t &spi_r);
unsigned ReadFromDRV8320S(unsigned addr , SPI_t &spi_r);
void supervisor_cores(server interface GUI_supervisor_interface supervisor_data  , in port p_button , in port p_fault , SPI_t &spi_r , port p_temp);
void init_TIdriver( SPI_t &spi_r);


#endif

/* SPI_H_ */
