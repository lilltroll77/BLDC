/*
 * spi.h
 *
 *  Created on: 23 sep 2018
 *      Author: Mikael Bohman
 */


#ifndef SPI_H_
#define SPI_H_

#include "typedefs.h"

enum message{SHUTDOWN=1 , DRV_ERROR=2 , DRV_SETTINGS=4 , TEMP_CHANGED=8 , FUSE_CHANGED=16 , LOAD_CHANGED=32 , FUSE_STATE=1<<24};

#define HISIDE_REG 3
#define LOSIDE_REG 4
#define TDRIVE_REG 4
#define ODT_REG 5
#define VDS_REG 5



interface GUI_supervisor_interface{
    [[notification]] slave void notification( void );
    [[clears_notification]] [[guarded]] int getInfo(void);
    [[guarded]] short readTemperature(char ID);
    [[guarded]] short readGateDriver(char reg);
    [[guarded]] int writeGateDriver(char reg , short data);
    [[guarded]] int resetGateDriver();
};

void WriteToDRV8320S(unsigned addr , unsigned data , SPI_t &spi_r , int ctrl);
unsigned ReadFromDRV8320S(unsigned addr , SPI_t &spi_r , int ctrl);
void supervisor_cores(server interface GUI_supervisor_interface supervisor_data  , in port p_button , in port p_fault , SPI_t &spi_r , port p_temp);
int init_TIdriver( SPI_t &spi_r );


#endif

/* SPI_H_ */
