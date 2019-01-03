/*
 * BasicIO.c - is a module with public functions used to send and receive
 * information from a serial port. In this case UART1 is configured for the
 * Segger debug USB serial port. FRDMK22F board.
 * v1.1
 *  Created by: Todd Morton, 10/09/2014
 *  With Contributions by: Jacob Gilbert And Adam Slater
 * v2.1
 *  Created by Todd Morton
 *  Contributions to BIOGetStrg() by Chance Eldridge
 *  Modified for K22F. Todd Morton, 01/07/2016
 */
/*********************************************************************
* Project master header file
********************************************************************/
#include "includes.h"

/********************************************************************
* Public Functions
********************************************************************/
void BIOOpen(void);
INT8C BIORead(void);
INT8C BIOGetChar(void);
void BIOWrite(INT8C c);
void BIOPutStrg(const INT8C *strg);
void BIOOutDecByte (INT8U bin, INT8U lz);
void BIOOutDecHWord (INT16U bin, INT8U lz);
INT8U BIOGetStrg(INT8U strglen,const INT8C *strg);
void BIOOutHexByte(INT8U bin);
void BIOOutHexHWord(INT16U bin);
void BIOOutCRLF(void);
void BIOOutHexWord(INT32U bin);
INT8U BIOHexStrgtoWord(const INT8C *strg,INT32U *bin);

/********************************************************************
* Private Resources
********************************************************************/
static INT8C bioHtoA(INT8U hnib);   //Convert nibble to ascii
static INT8U bioIsHex(INT8C c);
static INT8U bioHtoB(INT8C c);
/********************************************************************
* BIOOpen() - Initialization routine for BasicIO()
*    MCU: K22F, UART1 configured for debugger USB.
********************************************************************/
void BIOOpen(void){
	SIM_SCGC5 |= SIM_SCGC5_PORTE(1); 	/* Enable clock gate for PORTE */
    SIM_SCGC4 |= SIM_SCGC4_UART1(1); 	//enables UART1 clock (120MHz)

	PORTE_PCR0 = (0|PORT_PCR_MUX(3));    //ties peripherals to mux address
    PORTE_PCR1 = (0|PORT_PCR_MUX(3));
    UART1_BDH = 0x03;           		//sets clock divisor for 9600Hz Baud Rate
    UART1_BDL = 0x0d;           		//   120M / (16*781.25) = 9600
    UART1_C2 |= UART_C2_TE_MASK;    	//enables transmission
    UART1_C2 |= UART_C2_RE_MASK;    	//enables receive
    UART1_C4 = 8;                		//sets the .25 of divisor
}

/********************************************************************
* BIORead() - Checks for a character received
*    MCU: K22, UART1
*    return: ASCII character received or 0 if no character received
********************************************************************/
INT8C BIORead(void){
    INT8C c;
    if (UART1_S1 & UART_S1_RDRF_MASK){   //check if char received
        c = UART1_D;
    }else{
        c = 0;                           //If not return 0
    }
    return (c);
}
/********************************************************************
* BIOGetChar() - Blocks until character is received
*    return: INT8C ASCII character
********************************************************************/
INT8C BIOGetChar(void){
    INT8C c;
    do{
        c = BIORead();
    }while(c == 0);
    return c;
}

/********************************************************************
* BIOWrite() - Sends an ASCII character
*              Blocks as much as one character time
*    MCU: K22, UART1
*    parameter: c is the ASCII character to be sent
********************************************************************/
void BIOWrite(INT8C c){
    while (!(UART1_S1 & UART_S1_TDRE_MASK)){} //waits until transmission
    UART1_D = c;                             //is ready
}

/********************************************************************
* BIOPutStrg() - Writes a string to monitor
*    parameter: strg is a pointer to the ASCII string
********************************************************************/
void BIOPutStrg(const INT8C *strg){
    const INT8C *strgptr = strg;
    while (*strgptr != 0){              //until a null is reached
        BIOWrite(*strgptr);
        strgptr++;
    }
}

/********************************************************************
* BIOOutDecByte() - Outputs the decimal value of a byte.
*    Parameters: bin is the byte to be sent,
*                lz is true if leading zeros are sent
********************************************************************/
void BIOOutDecByte (INT8U bin, INT8U lz){
    INT8C digits[3];
    INT8U lbin = bin;
    INT8U zon = lz;
    digits[0]=(lbin%10) +'0';
    lbin = lbin/10;
    digits[1]=(lbin%10)+'0';
    digits[2]=lbin/10 +'0';

    if((digits[2] != '0') || (zon)){
        BIOWrite(digits[2]);
        zon = TRUE;
    }else{
    }
    if((digits[1] != '0') || (zon)){
        BIOWrite(digits[1]);
    }else{
    }
    BIOWrite(digits[0]);
}

/********************************************************************
* BIOOutDecHWord() - Outputs a decimal value of two bytes.
*    Parameters: bin is the half word to be sent,
*                lz is true if leading zeros are sent
********************************************************************/
void BIOOutDecHWord (INT16U bin, INT8U lz){
    INT8C digits[5];
    INT16U lbin = bin;
    INT8U zon = lz;
    digits[0]=(lbin%10) +'0';
    lbin = lbin/10;
    digits[1]=(lbin%10)+'0';
    lbin = lbin/10;
    digits[2]=(lbin%10)+'0';
    lbin = lbin/10;
    digits[3]=(lbin%10)+'0';
    digits[4]=lbin/10 +'0';

    if((digits[4] != '0') || (zon)){
        BIOWrite(digits[4]);
        zon = TRUE;
    }else{
    }
    if((digits[3] != '0') || (zon)){
        BIOWrite(digits[3]);
        zon = TRUE;
    }else{
    }
    if((digits[2] != '0') || (zon)){
        BIOWrite(digits[2]);
        zon = TRUE;
    }else{
    }
    if((digits[1] != '0') || (zon)){
        BIOWrite(digits[1]);
    }else{
    }
    BIOWrite(digits[0]);
    }

/********************************************************************
* BIOGetStrg() - Inputs a string and stores it into an array.
*
* Descritpion: A routine that inputs a character string to an array
*              until a carraige return is received or strglen is exceeded.
*              Only printable characters are recognized except carriage
*              return and backspace.
*              Backspace erases displayed character and array character.
*              A NULL is always placed at the end of the string.
*              All printable characters are echoed.
* Return value: 0 -> if ended with CR
*               1 -> if strglen exceeded.
* Arguments: *strg is a pointer to the string array
*            strglen is the max string length, includes CR/NULL.
********************************************************************/
INT8U BIOGetStrg(INT8U strglen,const INT8C *strg){
   INT8U charnum = 0;
   INT8C c;
   INT8C *strgp = (INT8C *)strg;
   INT8U rvalue = 1;
   c = BIOGetChar();
   while((c != '\r') && ((charnum <= strglen-1))){
       if((' ' <= c) && ('~' >= c) && (charnum < (strglen-1))){
           BIOWrite(c);
           *strgp = c;
           strgp++;
           charnum++;
           c=BIOGetChar();
       }else if((c == '\b') && (charnum <= (strglen - 1))){
           BIOWrite('\b');
           BIOWrite(' ');
           BIOWrite('\b');
           strgp--;
           charnum--;
           c=BIOGetChar();
       }else if((' ' <= c) && ('~' >= c) && (charnum <= (strglen - 1))){
           charnum++;
       }else{ /*non-printable character - ignore */
       }
   }
   BIOOutCRLF();
   *strgp = 0x00;
   if(c == '\r'){
       rvalue = 0;
   }else{
       rvalue = 1;
   }
   return rvalue;
}

/********************************************************************
* BIOOutCRLF() - Outputs a carriage return and line feed.
*
********************************************************************/
extern void BIOOutCRLF(void){
    BIOPutStrg("\r\n");
}

/********************************************************************
* BIOHexStrgtoWord() - Converts a string of hex characters to a 32-bit
*                      word until NULL is reached.
* Return value: 0 -> if no error.
*               1 -> if string is too long for word.
*               2 -> if a non-hex character is in the string.
*               3 -> No characters in string. Started with NULL.
* Arguments: *strg is a pointer to the string array
*            *bin is the word that will hold the converted string.
********************************************************************/
INT8U BIOHexStrgtoWord(const INT8C *strg,INT32U *bin){
    INT8U cnt = 0;
    INT32U lbin = 0;
    INT8C *strgptr = (INT8C *)strg;
    INT8U rval = 0;
    if(*strgptr == 0x00){
        rval = 3;
    }else{
        while(*strgptr != 0x00){
            if(bioIsHex(*strgptr)){
                lbin = (lbin << 4) | (INT32U)(bioHtoB(*strgptr));
            }else{
                rval = 2;
            }
            strgptr++;
            cnt++;
            if(cnt > 8){
                rval = 1;
            }else{
            }
        }
        *bin = lbin;
    }
    return rval;
}

/************************************************************************
* BIOOutHexByte() - Output one byte in hex.
* bin is the byte to be sent
*************************************************************************/
void BIOOutHexByte(INT8U bin){
    BIOWrite(bioHtoA(bin>>4));
    BIOWrite(bioHtoA(bin & 0x0f));
}

/************************************************************************
* BIOOutHexHWord() - Output 16-bit word in hex.
* bin is the word to be sent
*************************************************************************/
void BIOOutHexHWord(INT16U bin){
    BIOOutHexByte((INT8U)(bin>>8));
    BIOOutHexByte((INT8U)(bin & 0x00ff));
}
/************************************************************************
* BIOOutHexWord() - Output 32-bit word in hex.
* bin is the word to be sent
* Todd Morton, 10/14/2014
*************************************************************************/
void BIOOutHexWord(INT32U bin){
    BIOOutHexByte((INT8U)(bin>>24));
    BIOOutHexByte((INT8U)(bin>>16));
    BIOOutHexByte((INT8U)(bin>>8));
    BIOOutHexByte((INT8U)(bin & 0x000000ff));
}
/************************************************************************
* bioIsHex() - Checks for hex ascii character - private
* returns 1 if hex and 0 if not hex.
* Todd Morton, 10/14/2014
*************************************************************************/
static INT8U bioIsHex(INT8C c){
    INT8U rval;
    if((('0' <= c) && ('9' >= c)) || (('a' <= c) && ('f' >= c)) || (('A' <= c) && ('F' >= c))){
        rval = 1;
    }else{
        rval = 0;
    }
    return rval;
}

/************************************************************************
* bioHtoB() - Converts a hex ascii character to a binary byte - private
* c is the ascii character to be converted.
* returns the binary value.
* Note: it returns a 0 if it is not a hex character - this should be fixed.
* Todd Morton, 10/14/2014
*************************************************************************/
static INT8U bioHtoB(INT8C c){
    INT8U bin;
    if(('0' <= c) && ('9' >= c)){
        bin = c - '0';
    }else if(('a' <= c) && ('f' >= c)){
        bin = c - 'a' + 0xa;
    }else if(('A' <= c) && ('F' >= c)){
        bin = c - 'A' + 0xa;
    }else{
        bin = 0;
    }
    return bin;
}
/************************************************************************
* bioHtoA() - Converts a hex nibble to ASCII - private
* hnib is the byte with the LSN to be sent
* Todd Morton, 10/14/2014
*************************************************************************/
static INT8C bioHtoA(INT8U hnib){
    INT8C asciic;
    INT8U hnmask = hnib & 0x0f; /* Take care of any upper nibbles */
    if((hnmask & 0x0f) <= 9){
        asciic = (hnmask + 0x30);
    }else{
        asciic = (hnmask + 0x37);
    }
    return asciic;
}
