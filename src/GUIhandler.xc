/*
 * GUIhandler.xc
 *
 *  Created on: 25 sep 2018
 *      Author: micke
 */
#include "xud_cdc.h"
#include "print.h"
#include <stdio.h>
#include "xscope.h"
#include "supervisor.h"
#include "svm.h"



extern void wait(unsigned clk);

#define BUFF_LEN 16
#define HISIDE_REG 3
#define LOSIDE_REG 4
#define TDRIVE_REG 4
#define ODT_REG 5
#define VDS_REG 5


const int link_version=1;
const unsigned magicID= 3141592654;

void printDec(short data){
    printint(data/10);
    printchar('.');
    printint(data%10);
}
const float dec_factor = DECIMATE*DECIMATE*DECIMATE/MAXAMP;

unsigned Amp2FixPoint(float I , enum floatingpoint_scaletype scale_i){ //Amp to fixed point
    const float scale[] = {dec_factor , dec_factor*dec_factor };
    return I*scale[scale_i];
}

float FixPoint2Amp(unsigned I , enum floatingpoint_scaletype scale_i){ //Amp to fixed point
    const float scale[2] = {1 / dec_factor , 1 / (dec_factor * dec_factor) };
    return (float)I*scale[scale_i];
}

float FixPoint2Temp(unsigned t){ //Amp to fixed point
    return (float)t/16;
}
// !!! MUST MATCH enum COMMAND in GUI
enum COMMANDS{CLOSE_LINK , OPEN_LINK , LINK_VER , COM_CURRENT , COM_STOP, COM_DRV , COM_DRV_ERROR , COM_DRV_RESET ,COM_NEWTEMP , COM_FUSE_BLOWN , COM_FUSE_RESET , COM_FUSE_CURRENT, COM_VDS , COM_ODT , COM_TDRIVE , COM_IDRIVE_P_HS , COM_IDRIVE_N_HS , COM_IDRIVE_P_LS , COM_IDRIVE_N_LS , COM_SET_TORQUE , COM_SET_FLUX , COM_PI_FUSE , COM_PI_TORQUE_FREQ , COM_PI_TORQUE_GAIN , COM_PI_FLUX_FREQ , COM_PI_FLUX_GAIN , TIME_OUT ,CSERROR, SKIP};

enum DATA_TYPE{FIXED_POINT , FLOATING_POINT , DOUBLE};

enum BYTES{LENGTH , COMMAND , DATATYPE , CHECKSUM};

enum COMMANDS read_data(client interface usb_cdc_interface cdc , unsigned data[]){
    unsigned len=HEADER_SIZE;
    cdc.read( (data , char[]) , len);
    unsigned checksum =0;
    for(int i=0; i<CHECKSUM ;i++)
        checksum+=(data , char[])[i];
    len = (data , char[])[LENGTH] - HEADER_SIZE;
    enum COMMANDS command = (data , char[])[COMMAND];
    unsigned ref = (data , unsigned char[])[CHECKSUM];
    if(len > BUFF_LEN)
        return CSERROR;
    if(len==0){
        if((checksum & 0xFF) != ref)
            return CSERROR;
        return command;
    }
    int n=100;
    while(cdc.available_bytes()<(int) len){
        wait(1000);
        n--;
        if(n==0)
            return TIME_OUT; // timeout
    }
    cdc.read( (data , char[]) , len);
    for(int i=0; i < (int)len; i++)
        checksum+=(data , char[])[i];
    if((checksum & 0xFF) != ref)
        return CSERROR;
    return command;
}


void insertChecksum(unsigned char data[] , unsigned len){
    int checksum=0;
    data[CHECKSUM] =0;
    for(int i=0; i<len; i++)
        checksum += data[i];
    data[CHECKSUM] = checksum & 0xFF;

}

void write_command(client interface usb_cdc_interface cdc , enum COMMANDS command ,unsigned data[]){
    unsigned len=HEADER_SIZE;
    (data , char[])[LENGTH]=len;
    (data , char[])[COMMAND]=command;
    (data , char[])[DATATYPE]=0;
    insertChecksum((data , char[]) , len);
    cdc.write((data , char[]) , len);
    //cdc.flush_buffer();
    printstrln("Command written");
}

void write_uint(client interface usb_cdc_interface cdc , enum COMMANDS command , unsigned val ,unsigned data[]){
    unsigned len=HEADER_SIZE+sizeof(int);
    (data , char[])[LENGTH]=len;
    (data , char[])[COMMAND]=command;
    (data , char[])[DATATYPE]=FIXED_POINT;
    data[1] = val;
    insertChecksum((data , char[]) , len);
    cdc.write((data , char[]) , len);
    //cdc.flush_buffer();
    printstrln("uint written");
}

void write_float(client interface usb_cdc_interface cdc , enum COMMANDS command , float val , unsigned data[]){
    unsigned len=HEADER_SIZE+sizeof(float);
    (data , char[])[LENGTH]=len;
    (data , char[])[COMMAND]=command;
    (data , char[])[DATATYPE]=FLOATING_POINT;
    (data , float[])[1] = val;
    insertChecksum((data , char[]) , len);
    cdc.write((data , char[]) , len);
    //cdc.flush_buffer();
    printstrln("float written");
}

float write_temp(client interface usb_cdc_interface cdc , unsigned temp , unsigned data[]){
    unsigned len=HEADER_SIZE+sizeof(float);
    const float scale = (float)1/16;
    (data , char[])[LENGTH]=len;
    (data , char[])[COMMAND]=COM_NEWTEMP;
    (data , char[])[DATATYPE]=FLOATING_POINT;
    (data , float[])[1] = (float)temp*scale;
    insertChecksum((data , char[]) , len);
    cdc.write((data , char[]) , len);
    return (data , float[])[1];
}

{float , float}write_current(client interface usb_cdc_interface cdc , unsigned Ipeak , unsigned Ims , unsigned data[]){
    unsigned len=HEADER_SIZE+2*sizeof(float);
    (data , char[])[LENGTH]=len;
    (data , char[])[COMMAND]=COM_CURRENT;
    (data , char[])[DATATYPE]=FLOATING_POINT;
    (data , float[])[1] = FixPoint2Amp(Ipeak , Current);
    (data , float[])[2] = FixPoint2Amp(Ims , Energy);
    insertChecksum((data , char[]) , len);
    cdc.write((data , char[]) , len);
    return {(data , float[])[1] , (data , float[])[2] };
}

void write_TI_settings(client interface usb_cdc_interface cdc , client interface GUI_supervisor_interface supervisor , unsigned data[] , int error){   //Send DRV settings to host
    unsigned regs;
    if(error){
        (data , char[])[COMMAND]=COM_DRV_ERROR;
        regs=2;
    }else{
        (data , char[])[COMMAND]=COM_DRV;
        regs=6;
    }
    unsigned len = HEADER_SIZE+regs*sizeof(short);
    (data , char[])[LENGTH]=len;
    (data , char[])[DATATYPE]=FIXED_POINT;
    for(unsigned reg=0; reg <regs ; reg++)
        (data , short[])[reg + sizeof(short)] = supervisor.readGateDriver(reg);
    insertChecksum((data , char[]) , len);
    cdc.write((data , char[]) , len);
}



void parseData(client interface usb_cdc_interface cdc, client interface GUI_supervisor_interface supervisor , unsigned data[]  ,unsigned &link_up ){
    enum COMMANDS command;
    printstrln("read");
    command = read_data(cdc , data);
    printuintln(command);
    printuintln(data[0]);
    if(command == TIME_OUT){
        printstrln("GUI: Serial read timed out");
        return;
    }
    if(command == CSERROR){
        write_command(cdc , command , data);
        cdc.flush_buffer();
        printstrln("GUI: Checksum ERROR!");
        return;
    }
    switch(command){
    case CLOSE_LINK:
        printstrln("GUI: Link closed");
        cdc.flush_buffer();
        link_up =0;
        break;
    case OPEN_LINK:
        link_up=1;
        printstrln("GUI: Link opened");
        break;
    case LINK_VER:
        if(data[0] == magicID){
            write_uint(cdc , LINK_VER , link_version , data);
            printstrln("GUI: Link version sent");
        }else
            printstrln("GUI:Incorrect magic ID");
        break;
    case COM_DRV_RESET:
        printstrln("GUI: GateDriver reset");
        supervisor.resetGateDriver();
        write_TI_settings(cdc , supervisor , data , 0);
        break;
    case COM_VDS:
        short reg_data=supervisor.readGateDriver(VDS_REG);
        reg_data &=0xFF0;
        reg_data |=data[0];
        supervisor.writeGateDriver(VDS_REG , reg_data);
        printstr("GUI VDS: ");
        printhex(data[0]);printchar(',');printhexln(reg_data);
        break;
    case COM_ODT:
        short reg_data=supervisor.readGateDriver(ODT_REG);
        reg_data &=0x4FF;
        reg_data |=data[0]<<8;
        supervisor.writeGateDriver(ODT_REG , reg_data);
        printstr("GUI ODT:");
        printhex(data[0]);printchar(',');printhexln(reg_data);
        break;
    case COM_TDRIVE:
        short reg_data=supervisor.readGateDriver(TDRIVE_REG);
        reg_data &=0x4FF;
        reg_data |=data[0]<<8;
        supervisor.writeGateDriver(TDRIVE_REG , reg_data);
        printstr("GUI TDRIVE:");
        printhex(data[0]);printchar(',');printhexln(reg_data);
        break;
    case COM_IDRIVE_P_HS:
        short reg_data=supervisor.readGateDriver(HISIDE_REG);
        reg_data &=0xF0F;
        reg_data |=data[0]<<4;
        supervisor.writeGateDriver(HISIDE_REG , reg_data);
        printstr("GUI IDRIVE: P-HS ");
        printhex(data[0]);printchar(',');printhexln(reg_data);;
        break;
    case COM_IDRIVE_N_HS:
        short reg_data=supervisor.readGateDriver(HISIDE_REG);
        reg_data &=0xFF0;
        reg_data |=data[0];
        supervisor.writeGateDriver(HISIDE_REG , reg_data);
        printstr("GUI IDRIVE: N-HS ");
        printhex(data[0]);printchar(',');printhexln(reg_data);
        break;
    case COM_IDRIVE_P_LS:
        short reg_data=supervisor.readGateDriver(LOSIDE_REG);
        reg_data &=0xF0F;
        reg_data |=data[0]<<4;
        supervisor.writeGateDriver(LOSIDE_REG, reg_data);
        printstr("GUI IDRIVE: P-LS ");
        printhex(data[0]);printchar(',');printhexln(reg_data);
        break;
    case COM_IDRIVE_N_LS:
        short reg_data=supervisor.readGateDriver(LOSIDE_REG);
        reg_data &=0xFF0;
        reg_data |=data[0];
        supervisor.writeGateDriver(LOSIDE_REG , reg_data);
        printstr("GUI IDRIVE: N-LS ");
        printhex(data[0]);printchar(',');printhexln(reg_data);
        break;
        break;
    case COM_SET_TORQUE:
        printf("GUI: Torque Setpoint=%.2f%%" , (data[0] , float));
        break;
    case COM_SET_FLUX:
        printf("GUI: Flux Setpoint=%.2f%%" , (data[0] , float));
        break;
    case COM_FUSE_CURRENT:
        printf("GUI: FUSE:Max current=%.2f A" , (data[0] , float));
        unsigned Imax = Amp2FixPoint((data[0] , float) , Current);
        supervisor.setMaxCurrent(Imax);
        break;
    case COM_FUSE_RESET:
        supervisor.resetFuse();
        printstrln("GUI: RESET PRESSED");
        break;
    case COM_PI_TORQUE_FREQ:
        printf("GUI: PI Torque freq=%.2fHz" , (data[0] , float));
        break;
    case COM_PI_TORQUE_GAIN:
        printf("GUI: PI Torque gain=%.2fdB" , (data[0] , float));
        break;
    case COM_PI_FLUX_FREQ:
        printf("GUI: PI Flux freq=%.2fHz" , (data[0] , float));
        break;
    case COM_PI_FLUX_GAIN:
        printf("GUI: PI Flux gain=%.2fdB" , (data[0] , float));
        break;
        //TIME_OUT ,CSERROR, SKIP
    case TIME_OUT:
        printf("GUI: TIME OUT ERROR ");
        break;
    case CSERROR:
        printf("Checksum error detected");
        break;
    case SKIP:
        printf("GUI: SKIPPED COMMAND %d" , command);
        break;
    default:
        printstr("GUI: Unknown: ID=");
        printintln(command);
        break;
    }
}



[[combinable]] void GUIhandler(client interface usb_cdc_interface cdc , client interface GUI_supervisor_interface supervisor){
    set_core_high_priority_off();
    unsigned data[BUFF_LEN/sizeof(int)]={0};
    unsigned link_up=0;
    unsigned t;
    timer tmr;
    tmr:>t;

#define mSEC 1e5
    while(1){
        select{
        case tmr when timerafter(t+mSEC):>void:
        if(cdc.available_bytes()>=HEADER_SIZE){
            //parseData(cdc , supervisor , data , link_up );
        }
        tmr:>t;
        break;
        }
    }
}
/*
    while(1){
        select{
       case link_up => tmr when timerafter(t+(33*mSEC)):>void: // Send current
                unsigned Ipeak, Ims;
                {Ipeak , Ims}= supervisor.readCurrent();
                float Ipeakf, Imsf;
                {Ipeakf, Imsf} = write_current(cdc , Ipeak , Ims, data);
                //printf("Ip=%.3fA Ims%.3fA\n %d ,%d\n" , Ipeakf, Imsf , Ipeak, Ims );
                tmr:>t;
                break;
        case link_up => supervisor.data_waiting():
            int info = supervisor.getInfo();
            while(info != 0){
                   if(info &DRV_ERROR){ // Send error status reg to GUI
                        info &=~DRV_ERROR;
                        write_TI_settings(cdc , supervisor , data , 1);
                    }
                    if( info &SHUTDOWN ){
                        info &=~SHUTDOWN;
                        write_command(cdc , COM_STOP , data);
                        printstrln("GUI: Shutdown written");
                     }
                    if( info &TEMP_CHANGED ){
                        info &=~TEMP_CHANGED;
                        float temp = write_temp(cdc , supervisor.readTemperature(0) , data);
                        printf("GUI: Temp written %.2f C\n" , temp);
                    }
                    if(info &OVER_CURRENT){
                        info &=~OVER_CURRENT;
                        write_command(cdc , COM_FUSE_BLOWN , data);
                        printstrln("GUI: Overcurrent written");
                    }
            }
            break;
        case tmr when timerafter(t+mSEC):>void:
            if(cdc.available_bytes()>=HEADER_SIZE){
                parseData(cdc , supervisor , data , link_up );
            }
            tmr:>t;
            break;

        case cdc.data_ready():
            if(cdc.available_bytes()>=HEADER_SIZE)
                parseData(cdc , supervisor , data , link_up );
            wait(1000);
            break; //case cdc.data_ready()

        }//select


    }//while
}
*/
