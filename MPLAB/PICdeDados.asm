#include "P16F628A.inc"

; CONFIG
; __config 0x3F3C
 __CONFIG _FOSC_INTOSCIO & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _CP_OFF
 
 
#DEFINE BANK0 BCF STATUS, RP0
#DEFINE BANK1 BSF STATUS, RP0
 
#DEFINE Ctrl_in PORTB, 3
#DEFINE LED PORTB, 0

CBLOCK 0x70
    Contagem
    VAR1
    VAR2
    VAR3
ENDC

    ORG 0x0000
    GOTO INICIO

    ORG 0x0004
    RETFIE

;*********************************************************************************************;
DADOS: ; DT substitui uma sequência de RETLW
    MOVF Contagem, W
    ADDWF PCL
    DT "nnnnnnnnnnnnnn"
    GOTO $
    CLRF Contagem
    DT "n"

INICIO:
    BCF STATUS, RP1 ; Fixar bancos 0 e 1

    BANK1
    MOVLW 0xFF
    MOVWF TRISA
    MOVLW B'11111010'
    MOVWF TRISB

    BANK0
    BSF LED
    CALL DELAY_START
    BCF LED
    BANK1

    MOVLW .25
    MOVWF SPBRG
    
    MOVLW B'00100100'
    MOVWF TXSTA
    
    MOVLW B'10000000'
    MOVWF OPTION_REG
    
    BANK0
    MOVLW B'00000111'
    MOVWF CMCON
    
    MOVLW B'10000000'
    MOVWF RCSTA

    MOVLW B'11000000'
    MOVWF INTCON

    BCF LED
    CLRF Contagem

ENVIA_DADO:
    BTFSS Ctrl_in
    GOTO $-1
    
    CALL DADOS
	MOVWF TXREG
	BANK1
	BTFSS TXSTA, TRMT
	GOTO $-1
	BANK0
    INCF Contagem
    
    BTFSC Ctrl_in
    GOTO $-1
    
    BTFSS Ctrl_in
    GOTO $-1
    BSF LED
    
    BTFSC Ctrl_in
    GOTO $-1
    BCF LED

    BTFSS Ctrl_in
    GOTO $-1
    BSF LED
    
    BTFSC Ctrl_in
    GOTO $-1
    BCF LED
    
    GOTO ENVIA_DADO
			
;*********************************************************************************************;

DELAY_START
			;993 cycles
	movlw	0xC6
	movwf	VAR1
	movlw	0x01
	movwf	VAR2
DELAY_START_0
	decfsz	VAR1, f
	goto	$+2
	decfsz	VAR2, f
	goto	DELAY_START_0

			;3 cycles
	goto	$+1
	nop

			;4 cycles (including call)
	return

;*********************************************************************************************;


    END


