/*************************************************************************
* includes.h - Master header file template for ARM Cortex-M projects.
*
* TDM 09/30/2014
**************************************************************************
* Make sure it is only included one time
*************************************************************************/
#ifndef  INCLUDES_PRESENT
#define  INCLUDES_PRESENT
/**************************************************************************
* General type definitions 
*************************************************************************/
typedef char   				INT8C;
typedef unsigned char   	INT8U;
typedef signed char     	INT8S;
typedef unsigned short  	INT16U;
typedef signed short    	INT16S;
typedef unsigned int    	INT32U;
typedef signed int      	INT32S;
typedef unsigned long long  INT64U;
typedef signed long long   	INT64S;
typedef float				FP32;
typedef double				FP64;

/*************************************************************************
* General Defined Constants 
*************************************************************************/
#define FALSE    0
#define TRUE     1

/*************************************************************************
* General defined macros 
*************************************************************************/
#define TRAP() while(1){}

/*************************************************************************
* MCU specific definitions
*************************************************************************/
#include "MK22F51212.h" 	 /* include peripheral declarations */

#define DISABLE_INT()  asm("CPSID i \n")
#define ENABLE_INT()  asm("CPSIE i \n")

/*************************************************************************
* Project Constant and Macro Definitions
*************************************************************************/

/*************************************************************************
* System Header Files 
*************************************************************************/
#include <string.h>
#include <stdlib.h>
#include "BasicIO.h"
/*************************************************************************
* Module Header Files or Declarations 
*************************************************************************/

/************************************************************************/
#endif
