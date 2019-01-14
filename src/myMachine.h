/*
 * myMachine.h
 *
 *  Created on: 14 jan 2019
 *      Author: micke
 */

#ifndef MYMACHINE_H_
#define MYMACHINE_H_

//Set to one for calibrating your QE and ADC
#define CALIBRATE_QE 0

#define Rsense 2 //mOhm or +-32A (25A linear)
//The ADC output for 1A current
//Peak to peak value = 1<<21
#define AMPERE (Rsense<<14) //

//ADC output at 0 amp
#define ADC_0Amp (1<<20)
//ADC offsets
#define ADC_OFFSET_A (ADC_0Amp - 940)
#define ADC_OFFSET_C (ADC_0Amp - 1300)

//Motor magnets per ½ rev
#define MOTOR_MAG 7

//QE encoder ticks per rev
#define QE_RES 8192

// Direction for motor vs QE encoder
#define DIRECTION (-1) // Can be 1 or (-1)

//QE encoder offset between trig position and FOCangle = 0 deg [QE ticks]
#define QE_OFFSET 409

// Motor phases
#define PHASES 3
#define FOC_SECTORS (2*PHASES)

#endif /* MYMACHINE_H_ */
