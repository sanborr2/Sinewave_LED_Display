/******************************************************************************
* 			For : Professor Sandelin, of WWU
* 	 Assignment : EE244, Lab 4
*
* 	Description : Sinewave Display,
*				  Program that creates sinewave across LEDS[7:0] on the FDRM Shield
*				  given frequency input by user either via switches or the Terminal.
* 				  Frequency must be whole decimal number minimum of 1 Hz,
*                  maximum of 63 Hz.
*
*           MCU : K22F,
*       Assuming: Fsys = 200MHz
* Supporting Libraries:
*				  BasicIO.c by Professor Todd Morton of WWU
*        Author : Robert Sanborn
*         Date  : 3/13/28
******************************************************************************/
                .syntax unified        /* define Syntax */
                .cpu cortex-m4
                .fpu fpv4-sp-d16
                .globl main            /* make main() global so outside file */
                                       /* can see it. Required for startup   */
/******************************************************************************
 * Equates
 *****************************************************************************/

                .equ ZERO, 0x0                            /* Some Constants for shifting */
                .equ ONE, 0x1                             /*  and incrementing values    */
                .equ TWO, 0x2
                .equ THREE, 0x3
                .equ FIVE, 0x5
                .equ SIX, 0x6
                .equ EIGHT, 0x8
                .equ TEN, 0xA
                .equ SIXTEEN, 0x10
                .equ SEVENTEEN, 0x11
                .equ EIGHTEEN, 0x12
                .equ TWENTY, 0x14

                .equ P_TWO_FIVE, 0x2000                    /* Values to compare Q15 numbers to, to determine relatvie value */
                .equ P_FIVE, 0x4000
                .equ P_SEVEN_FIVE, 0x6000
                .equ ONE_ZERO, 0x8000
                .equ ONE_TWO_FIVE, 0xA000
                .equ ONE_FIVE, 0xC000
                .equ ONE_SEVEN_FIVE, 0xE000

                .equ LED0, 0x01                            /* BitMasks for setting LBits to turn on the appropriate LED*/
                .equ LED1, 0x02
                .equ LED2, 0x04
                .equ LED3, 0x08
                .equ LED4, 0x10
                .equ LED5, 0x20
                .equ LED6, 0x40
                .equ LED7, 0x80

                .equ MAX_INPUT, 63
                .equ MILLION, 1000000

                .equ SIXTY_FIFTH_ENTRY, 0x80               /* BitMask value for the address just beyond the very */
                										   /* last entry the Look-up Sine Table */

                .equ TC1US, 40                             /* Number of cycles that takes approx 1 microsecond to execute */
                                                           /* Assume Fsys = 200MHz*/

                .equ ASCII_TO_BIN, 0x30

                .equ BM_POTRB_C_D_CLKS_ON, 0x1C00          /* Bitmask to activate Port Clocks for LED and Switches */
                .equ SIM_SCGC5, 0x40048038

                .equ PORTC_PCR2, 0x4004B008
                .equ PORTx_PCRn_OFFSET, 0x4

                .equ PORTB_PCR0, 0x4004A000
                .equ OFFSET_PORTB_PCR16, 0x40
                .equ OFFSET_PORTB_PCR18, 0x48

                .equ PORTD_PCR2, 0x4004C008

                .equ GPIOD_PDOR, 0x400FF0C0
                .equ BM_LEDOUT_GPIOD_PDDR, 0x1C            /* Bit Mask that sets LED[2:0] Connections to Output */

                .equ GPIOB_PDOR, 0x400FF040
                .equ BM_LEDOUT_GPIOB_PDDR, (0xD<<16)+0x3   /* Bit Mask that sets LED[7:3] Connections to Output */


                .equ GPIOC_PDOR, 0x400FF080
                .equ BM_SWIN_GPIOC_PDDR, ~(0xFF<<2)        /* Bit Mask that sets SW[7:0] Connections to Input  */

                .equ BM_SW_PULLUP_EN, 0x03                 /* Bit Mask that enables and toggles Pullup Resistor for SWITCH[7:0] */

                .equ GPIOx_PDDR_OFFSET, 0x14
                .equ GPIOx_PDIR_OFFSET, 0x10


                .equ PORT_PCR_MUX_ALT1, 0x01<<8            /* Enable Code for MUX field in PORTx_PCRn */

/******************************************************************************
 * main program code
 *****************************************************************************/
                .section .text
main:
				bl IOShieldIni          /*  Initialize the FDRM Board for K22F */
				bl BIOOpen              /*  Initialize serial port  */

				ldr r6, =UserPrompt
				ldr r5, =InvalidNotify
				ldr r8, =SineTable

mainloop:
				/*		        Check Status of Switches	       */
				bl SwArrayRead
				cmp r0, #ZERO
				mov r7, r0                 /*Preserve LastSwStatus in r7*/

				/* If Switch input is nonzero, ignore terminal*/

				mrs r4, apsr              /* Preserve status flags against both possible calls*/
				ittt ne
				movne r1, r7
				movne r2, r8
				blne DisplayWave            /* Pass Frequency from Switches, LastSwStatus, and SineTable pointer*/
				msr apsr_nzcvq, r4


				/* Otherwise continuously read from the terminal until given a valid frequency*/
				mrs r4, apsr
				itttt eq
				ldreq r0, =UserFrequency
				moveq r1, r6
				moveq r2, r5
				bleq ReadTerminal
				msr apsr_nzcvq, r4

				mrs r4, apsr
				ittt eq
				moveq r1, r7
				moveq r2, r8
				bleq DisplayWave            /* Pass Frequency from Terminal, LastSwStatus, and SineTable pointer*/
				msr apsr_nzcvq, r4

				b mainloop


/************************************************************************************************
 * void ReadTerminal(INT32U us, INT8U LastSwStatus)
 *
 * This subroutine sets the period	for the sinewave to be displayed on the IO FDRM Sheild LEDs
 *
 *  Params: UserFrequency,
 *          variable passed by reference that is used as strg pointer for user input from terminal
 *          UserPrompt, strg pointer to user prompt string
 *          InvalidNotify, strg pointer to invalid notification string printed to terminal after
 *
 *
 * Corrupts: r4-9, aspr
 * Returns: Frequency, 32-bit unsigned int that represents the frequency of the LED sinewave
 *
 *     MCU: K22F, IO FDRM Sheild
 * Supporting Libraries:
 *				  BasicIO.c by Professor Todd Morton of WWU
 *Assuming: Fsys = 200MHz
 *
 * Robert Sanborn, 3/13/18
 *************************************************************************************************/
ReadTerminal:
			 	push {lr}
				push {r4, r5, r6, r7, r8, r9}

				mov r7, r0                      /* Preserve UserFrequency*/
				mov r8, r1					    /* UserPrompt*/
				mov r9, r2					    /* InvalidNotify*/

readinputs:     bl BIOOutCRLF

				/*       If Switches are all off, begin reading the Terminal           */
				mov r0, r8            /* Output question to user on screen*/
				bl BIOPutStrg


				ldr r0, =THREE
				mov r1, r7
				bl BIOGetStrg

				cmp r0, #ZERO                   /* If user typed an input too long send invalid notification */
				bne invalidinput


				/*   Get first digit  */
				ldrb r5, [r7]
				mov r0, r5
				bl IsDigit

				cmp r0, #ZERO
				bne invalidinput

				sub r5, #ASCII_TO_BIN

				/*   Get possible second digit  */
				ldrb r4, [r7, #ONE]
				mov r0, r4
				bl IsDigit

				cmp r4, #ZERO                   /* if user specifies one digit, calculate frequency using one digit*/
				ittte eq
				ldreq r0, =ZERO
				ldreq r6, =ONE
				ldreq r4, ='0
				ldrne r6, =TEN

				sub r4, #ASCII_TO_BIN           /* Use mask value to convert to Bin  */

				cmp r0, #ZERO
				bne invalidinput                /* Handle invalid input */


				/* Calculate two digit decimal number, Frequency */
				mul r5, r6
				add r0, r5, r4

 				/* If user input greater than 63, notify them input is invalid */
				cmp r0, #MAX_INPUT
				bgt invalidinput

				/* Check to make certain input is not zero*/
				cmp r0, #ZERO
				it ne                            /* If Everything Checks out begin display process */
				bne done

				/*            Handle Invalid Inputs        */
invalidinput:
				bl BIOOutCRLF
				mov r0, r9
				bl BIOPutStrg

				b readinputs

done:
				pop {r4, r5, r6, r7, r8, r9}
				pop {pc}



/**********************************************************************************************
 * void DisplayWave(INT32U us, INT8U LastSwStatus) -This subroutine continuously
 *								 modifies the LED Display on the IO FDRM Shield
 *                               to make a sinewave.
 *
 *  Params: Frequency, 32-bit unsigned int that represents the frequency of the LED sinewave
 * 	     LastSwStatus, 8 bit signed int that represents most previous status of switches
 			SineTable, pointer to Lookup table of values for 1 + sin(i/64*2pi*f)
 * Corrupts: r4-7, aspr
 * Returns: none
 *     MCU: K22F, IO FDRM Sheild
 * Supporting Libraries:
 *				  BasicIO.c by Professor Todd Morton of WWU
 *Assuming: Fsys = 200MHz
 *
 * Robert Sanborn, 3/9/18
 ***********************************************************************************************/
DisplayWave:
		        push {lr}
				push {r4, r5, r6, r7}

				/* Make copies of LastSwStatus and SineTable*/
				mov r7, r1
				mov r5, r2

				/*			Begin Process of creating Sine Wave                      */

				USAT r4, #SIX, r0               /* Saturate frequency to 63 Hz if not already done so for sanity's sake*/
				lsl r4, #SIX                    /* (freq x 64) */
			    ldr r3, =MILLION
			    udiv r0, r3, r4                 /* Calculate Period, us, as 10^6/(64*freq), */
			    					            /* result is in micro seconds*/

			    mov r6, r0                      /* Make copy of us and SineTable */
				mov r4, r5

				cmp r1, #ZERO                   /* If Switch inputs are still off output carriage return on terminal*/
				it eq
			    bleq BIOOutCRLF


sineloop:		ldrh r3, [r4], #TWO

                /* Check what range the value is in, pass the correct LBits value to LEDWrite */

				ldr r2, =P_TWO_FIVE             /* Is value in range of [0.00 : 0.25)? */
				cmp r3, r2
				itt lt
				ldrlt r0, =LED0
				blt call_ledwrite

				ldr r2, =P_FIVE                 /* Is value in range of [0.25 : 0.50)? */
				cmp r3, r2
				itt lt
				ldrlt r0, =LED1
				blt call_ledwrite

				ldr r2, =P_SEVEN_FIVE           /* Is value in range of [0.50 : 0.75)? */
				cmp r3, r2
				itt lt
				ldrlt r0, =LED2
				blt call_ledwrite

				ldr r2, =ONE_ZERO               /* Is value in range of [0.75 : 1.00)? */
				cmp r3, r2
				itt lt
				ldrlt r0, =LED3
				blt call_ledwrite

				ldr r2, =ONE_TWO_FIVE           /* Is value in range of [1.00 : 1.25)? */
				cmp r3, r2
				itt lt
				ldrlt r0, =LED4
				blt call_ledwrite

				ldr r2, =ONE_FIVE               /* Is value in range of [1.25 : 1.50)? */
				cmp r3, r2
				itt lt
				ldrlt r0, =LED5
				blt call_ledwrite

				ldr r2, =ONE_SEVEN_FIVE         /* Is value in range of [1.50 : 1.75)? */
				cmp r3, r2
				itt lt
				ldrlt r0, =LED6
				blt call_ledwrite

				ldr r0, =LED7                   /* Assume at this point that value of sine table */
											    /*  is in range of [1.75 : 2.00] */

call_ledwrite:  bl LEDWrite

				/* Create Delay time to wait for certian period of time */
				mov r0, r6
				bl Delayus

				/* Check if all entries have been iterated over */

				mov r1, r5                     /* Use Bitmask of value 0x80 (128) to obtain address  */
				ldr r2, =SIXTY_FIFTH_ENTRY	   /*  of "sixty-fifth" entry, or the first address */
				add r1, r2  				   /*  just after the sine table*/

				cmp r4, r1
				it eq
				moveq r4, r5

				/* Check status of switches for change */
				bl SwArrayRead
				cmp r0, r7
				bne finish

				cmp r0, #ZERO
				bne sineloop

				/* Check r0 for q value as sign user has ended sine wave at given frequency if frequency is zero */
				bl BIORead
				cmp r0, 'q
				beq finish

				b sineloop

 /*             End Sinewave Display           */
finish:	        ldr r0, =ZERO
				bl LEDWrite

			    bl BIORead             /* Clear UART buffer with BIORead */

				pop {r4, r5, r6, r7}
				pop {pc}




/**********************************************************************************
 * void Delayus(INT32U us)
 *
 *   Params: us, 32 bit unsigned integer that specifies how long
 *				   delay loop must last in microseconds
 *  Returns: none
 *      MCU: K22F
 *Assumming: Fsys = 200MHz
 *
 * Robert Sanborn, 3/9/18
 **********************************************************************************/
Delayus:        push {lr}
				mov r1, #TC1US
				mul r2, r0, r1
				sub r2, #TWO

/* Delay lasts for "us" microseconds */
loop:           subs r2, #1
				bne loop

				sub r1, r1
				pop {pc}


/******************************************************************************
 * void LEDWrite(LBits) - This subroutine updates display of LED for FRDM-K22F
 *
 *  Params: LBits, 8-bit unsigned integer
 * Returns: none
 *     MCU: K22F, using IO FDRM Shield
 *
 * Robert Sanborn, 3/9/18
 *****************************************************************************/
LEDWrite:       push {lr}

                sub r1, r1
                sub r2, r2

                /* Manipulate LBits into format for GPIOB_PDOR and GPIOD_PDOR */
                lsl r0, #TWO
                bfi r1, r0, #ZERO, #FIVE               /* Extract bits for updating LED[2:0] into r1*/

                lsr r0, #FIVE
                bfi r1, r0, #ZERO, #TWO                /* Extract bits for updating LED[7:3] and  place into r1*/
                lsr r0, #TWO
                lsl r0, #SIXTEEN
                bfi r2, r0, #ZERO, #SEVENTEEN
                lsl r0, #ONE
                orr r0, r2
                orr r0, r1                             /* Place bits for all  in r0 */

                /* Extract bits for correct GPIOx_PDOR to update correct LED(s) */
                mvn r0, r0                             /* Make value Active LOW to be used to update LED */

                ldr r2, =GPIOD_PDOR                    /* Update status of LED[2:0] on IO FDRM Shield */
                ldr r3, [r2]
                mov r1, r3
                bfi r1, r0, #ZERO, #FIVE
                bfi r1, r3, #ZERO, #TWO
                str r1, [r2]

                ldr r2, =GPIOB_PDOR                    /* Update status of LED[7:3] on IO FDRM Shield*/
                ldr r3, [r2]
                mov r1, r3
                bfi r1, r0, #ZERO, #TWENTY
                bfi r1, r3, #ZERO, #EIGHTEEN
                bfi r1, r0, #ZERO, #SEVENTEEN
                bfi r1, r3, #ZERO, #SIXTEEN
                bfi r1, r0, #ZERO, #TWO
                str r1, [r2]

                pop {pc}                               /* Return */


/**********************************************************************************
 * INT8U IsDigit(INT8C) -This subroutine outputs an 8-bit unsigned integer
 *
 *  Params: Ascii character in r0, as a 1 byte signed int
 * Returns: 0 -> if valid decimal digit
 * 			1 -> if not valid decimal digit
 *     MCU: K22F
 *
 * Robert Sanborn, 3/9/18
 **********************************************************************************/
IsDigit:        push {lr}
				ldr r1, =0

				cmp r0, #'0       /* If INT8C is not an ascii number*/
				it lt             /*  return a 1 in r0 */
				ldrlt r1, =1

				cmp r0, #'9
				it gt
				ldrgt r1, =1

				mov r0, r1
				pop {pc}

/**********************************************************************************
 * INT8U SwArrayRead(void) -This subroutine outputs an 8-bit unsigned integer
 *
 *  Params: None
 * Returns: 8-bit unsigned integer, SwStatus, representing status of switches[7:0]
 *     MCU: K22F, using IO FDRM Shield
 *
 * Robert Sanborn, 3/9/18
 **********************************************************************************/
SwArrayRead:    push {lr}

                ldr r3, =GPIOC_PDOR
                ldr r2, [r3, #GPIOx_PDIR_OFFSET]         /* Read status of Switches on GPIOC_PDIR */
                lsr r2, #TWO
                ldr r0, =ZERO
                bfi r0, r2, #ZERO, #EIGHT                /* Save 8 bits representing the status of 8 switches  */

                pop {pc}


/******************************************************************************
 * void IO_Shield_Ini(void) - This subroutine initializes the LED Display
 *                            and Switches on FRDM-K22F
 *  Params: None
 * Returns: None
 *     MCU: K22F, using IO FDRM Shield
 *
 * Robert Sanborn, 3/9/18
 *****************************************************************************/
IOShieldIni:    push {lr}

                /* Initialize Clock Gate for Ports B, C, and D */
				ldr r0, =SIM_SCGC5
                ldr r2, [r0]
                orr r2, #BM_POTRB_C_D_CLKS_ON
                str r2, [r0]

                /*                Initialize Ports for LED and Switches                   */

				/* Initialize PORT D Data Direction Register for LED[2:0] to make Outputs */
                ldr r1, =GPIOD_PDOR
                ldr r3, [r1, #GPIOx_PDDR_OFFSET]
                orr r3, #BM_LEDOUT_GPIOD_PDDR        /* Bit Mask for initializing LED[2:0]*/
                str r3, [r1, #GPIOx_PDDR_OFFSET]

                /* Initialize PORT B Data Direction Register for LED[7:3] to make Outputs*/
                ldr r1, =GPIOB_PDOR
                ldr r3, [r1, #GPIOx_PDDR_OFFSET]
                ldr r2, =BM_LEDOUT_GPIOB_PDDR        /* Bit Mask for initializing LED[7:3] to make Outputs*/
                orr r3, r2
                str r3, [r1, #GPIOx_PDDR_OFFSET]


                /* Initialize PORT C Data Direction register for Switches to become Inputs*/
                ldr r1, =GPIOC_PDOR
                ldr r3, [r1, #GPIOx_PDDR_OFFSET]
                ldr r2, =BM_SWIN_GPIOC_PDDR
                and r3, r2                               /* Bit Mask for initializing SWITCH[7:0]*/
                str r3, [r1, #GPIOx_PDDR_OFFSET]

				/*                  Initialize LEDs as all off                             */

				/* Initialize the GPIOD_PDOR for LED[2:0] to off state */
                ldr r1, =GPIOD_PDOR
                ldr r3, [r1]
                orr r3, #BM_LEDOUT_GPIOD_PDDR        /* Reuse GPIOD_PDDR mask to initailize LED[2:0] as off */
                str r3, [r1]

                /* Initialize the GPIOB_PDDR for LED[7:3] to off state */
                ldr r1, =GPIOB_PDOR
                ldr r3, [r1]
                ldr r2, =BM_LEDOUT_GPIOB_PDDR
                orr r3, r2                           /* Use Mask for GPIOB_PDDR for PORTB to */
                str r3, [r1]

				/*              Initialize PCRs for LEDs and Switches                   */

                /* Initialize Pin Control Registers for LED[2:0] on PORTD */
                ldr r0, =PORTD_PCR2
                ldr r1, =PORT_PCR_MUX_ALT1
                str r1, [r0], #PORTx_PCRn_OFFSET
                str r1, [r0], #PORTx_PCRn_OFFSET
                str r1, [r0]

                /* Initialize Pin Control Registers for LED[7:3] on PORTD */
                ldr r0, =PORTB_PCR0
                str r1, [r0]                             /* r1 still has PORT_PCR_MUX_ALT1*/
                str r1, [r0, #PORTx_PCRn_OFFSET]
                str r1, [r0, #OFFSET_PORTB_PCR16]
                str r1, [r0, #OFFSET_PORTB_PCR18]!
                str r1, [r0, #PORTx_PCRn_OFFSET]

  				/* Initialize Pin Control Registers for SWITCH[7:0] on PORTC    */
                ldr r0, =PORTC_PCR2
                orr r1, #BM_SW_PULLUP_EN                  /* r1 now MUX Enable OR'ed with Pullup Resistor Enable Code for Switches*/
                str r1, [r0], #PORTx_PCRn_OFFSET
                str r1, [r0], #PORTx_PCRn_OFFSET
                str r1, [r0], #PORTx_PCRn_OFFSET
                str r1, [r0], #PORTx_PCRn_OFFSET
                str r1, [r0], #PORTx_PCRn_OFFSET
                str r1, [r0], #PORTx_PCRn_OFFSET
                str r1, [r0], #PORTx_PCRn_OFFSET
                str r1, [r0]

                pop {pc}                                 /* Return to Main, Initialization finished*/


/******************************************************************************
* Stored Constants
******************************************************************************/
                .section .rodata

UserPrompt:     .asciz "Hello User, enter a desired frequency for your sinewave. Input can only be a two digit number between 1 and 63 Hz.\n\r Please enter a frequency "

InvalidNotify:  .asciz "Invalid input, try again.\n\r"


          /* 64-entry Look-Up Table in Q15 for values of  */
          /*  f(i) = 1+sin(2*pi*i/64) where i is */
          /*  the ith entry in the table */
SineTable:      .2byte 0x8C8B, 0x98F8, 0xA528, 0xB0FB
				.2byte 0xBC56, 0xC71C, 0xD133, 0xDA82
				.2byte 0xE2F2, 0xEA6D, 0xF0E2, 0xF641
			    .2byte 0xFA7D, 0xFD8A, 0xFF62, 0xFFFF
				.2byte 0xFF62, 0xFD8A, 0xFA7D, 0xF641
				.2byte 0xF0E2, 0xEA6D, 0xE2F2, 0xDA82
				.2byte 0xD133, 0xC71C, 0xBC56, 0xB0FB
				.2byte 0xA528, 0x98F8, 0x8C8B, 0x8000
				.2byte 0x7374, 0x6707, 0x5AD7, 0x4F04
				.2byte 0x43A9, 0x38E3, 0x2ECC, 0x257D
				.2byte 0x1D0D, 0x1592, 0x0F1D, 0x09BE
				.2byte 0x0582, 0x0275, 0x009D, 0x0000
				.2byte 0x009D, 0x0275, 0x0582, 0x09BE
				.2byte 0x0F1D, 0x1592, 0x1D0D, 0x257D
				.2byte 0x2ECC, 0x38E3, 0x43A9, 0x4F04
				.2byte 0x5AD7, 0x6707, 0x7374, 0x7FFF

/******************************************************************************
* Variables
******************************************************************************/
                .section .bss

                .comm UserFrequency, 3

