;*********************************************************************************************;
;				Projeto MICROS
;*********************************************************************************************;
#INCLUDE <P16F628A.INC>
 __CONFIG _FOSC_INTOSCIO&_WDTE_OFF&_PWRTE_OFF&_MCLRE_OFF&_BOREN_OFF&_LVP_OFF&_CPD_OFF&_CP_OFF
;*********************************************************************************************;
;				DEFINICOES
;*********************************************************************************************;
#DEFINE BANK0 BCF STATUS, RP0
#DEFINE BANK1 BSF STATUS, RP0

#DEFINE Ctrl PORTB, 0 ; "Sinal de controle"
#DEFINE _PONTO PORTB, 3 ; Ponto decimal que indica qual hexadecimal está sendo mostrado

PASSOS EQU .96	    ; Numero total de passos (contando meio-passo)
PASSOS_2 EQU .48

;*********************************************************************************************;
;				REGISTRADORES DE USO GERAL
;*********************************************************************************************;
    CBLOCK 0x70
	BYTE	    ; Guarda o valor recebido pela serial
	TARGET	    ; Indica a posicao para a qual o motor deve ir*
	POSITION    ; Indica a posicao atual do motor*
	DIF	    ; Usado para iteracoes
	BOBINA_8    ; 0-7 : Indica, a partir da tabela 1, o estado de acionamento das bobinas
	CONTAGEM    ; Valor a ser mostrado no display (indica o ï¿½ndice do caractere)
	VAR1
	VAR2
	VAR3
    ENDC

;*********************************************************************************************;
;				     START
;*********************************************************************************************;
    ORG 0X00
	
	GOTO MAIN
;*********************************************************************************************;
;				     INTERRUPCAO
;*********************************************************************************************;
    ORG 0X04
	
	BANK0
	MOVF RCREG, W
	MOVWF BYTE
	BCF Ctrl ; Desativa o pedido de dados a linha
	BCF RCSTA, CREN ; Desabilita a interrupcao serial enquanto nao processar o valor atual
	RETFIE

;*********************************************************************************************;
;					MAIN
;*********************************************************************************************;
MAIN:
	BCF STATUS, RP1 ; Fixar em bancos 0 e 1
	
	BANK1
	CLRF TRISA ; Pinos do PORTA sao todos saida (exceto RA5)
	MOVLW B'00000110'
	MOVWF TRISB ; 
	
	MOVLW .25
	MOVWF SPBRG ; BaudRate em 9600
	BSF PIE1, RCIE ; Habilitar interrupcao de Recepcao Serial
	MOVLW B'00100100'
	MOVWF TXSTA
	
	BANK0 
	MOVLW B'10010000'
	MOVWF RCSTA ; Habilita comunicacao serial e recepcao continua.
	
	MOVLW B'00000111'
	MOVWF CMCON ; Desativar modulo comparador para usar RA0:RA3 como I/O
	
	MOVLW B'10011111'
	MOVWF PORTA ; Coloca "-" no display
	MOVLW B'00110000'
	CLRF CONTAGEM

	MOVLW .1
	MOVWF BOBINA_8
	CALL TABELA_BOBINA
	IORLW B'00001000'
	MOVWF PORTB
	CLRF POSITION

	MOVLW B'11000000' ; Habilitar interrupcao Geral e de Perifericos
	MOVWF INTCON
	
	BSF Ctrl ; Solicita primeiro dado

;*********************************************************************************************;
;				    ROTINA PRINCIPAL
;*********************************************************************************************;
LOOP:
	BTFSC Ctrl ; Esse teste so se torna verdadeiro se recepcao serial gerar uma interrupcao
	GOTO LOOP
    ;---------------------------------------
	CALL DISPLAY
	MOVWF PORTA ; Escreve no display a contagem
    ;---------------------------------------
	BSF _PONTO
	CALL TRATA ; Target e' definido
	CALL TRAJETO
	
	BSF Ctrl
	CALL DELAY_FLAG
	BCF Ctrl
    ;---------------------------------------
	BCF _PONTO
	CALL TRATA ; Move agora para a parte baixa
	CALL TRAJETO
	
	BSF Ctrl
	CALL DELAY_FLAG
	BCF Ctrl
    ;---------------------------------------
	GOTO $+1
	GOTO $+1 ; Pequeno delay para evitar erros de leitura pelo PIC de Dados
	
	BSF RCSTA, CREN ; Reabilita a recepcao serial
	BSF Ctrl ; Solicita novo dado a linha
	GOTO LOOP
	
;*********************************************************************************************;
;				    DISPLAY
; Gerencia contagem (a partir de 1) de caracteres recebidos pela serial
; Retorna valor a ser escrito em PORTA / pinout = fg_edcba
; Deve ser usado com display de sete segmentos do tipo ânodo comum
;*********************************************************************************************;	
DISPLAY:
	INCF CONTAGEM
	MOVF CONTAGEM, W
	ADDWF PCL
	RETLW B'01000000'	; 0
	RETLW B'11011001'	; 1
	RETLW B'10000100'	; 2
	RETLW B'10010000'	; 3
	RETLW B'00011001'	; 4
	RETLW B'00010010'	; 5
	RETLW B'00000010'	; 6
	RETLW B'01011000'	; 7
	RETLW B'00000000'	; 8
	RETLW B'00010000'	; 9
	RETLW B'00001000'	; A
	RETLW B'00000011'	; B
	RETLW B'01000110'	; C
	RETLW B'10000001'	; D
	RETLW B'00000110'	; E
	CLRF CONTAGEM
	RETLW B'00001110'	; F

;*********************************************************************************************;
; 				TRATAMENTO DE BYTE
; Gerencia a ordem de leitura dos nibbles
; Atualiza valor de TARGET
;*********************************************************************************************;
TRATA: 
	SWAPF BYTE
	MOVLW B'00001111'
	ANDWF BYTE, W
	CALL TABELA_POSICIONA
	MOVWF TARGET
	RETURN
TABELA_POSICIONA:
	ADDWF PCL
	RETLW .3	; 0
	RETLW .9	; 1
	RETLW .15	; 2
	RETLW .21	; 3
	RETLW .27	; 4
	RETLW .33	; 5
	RETLW .39	; 6
	RETLW .45	; 7
	RETLW .51	; 8
	RETLW .57	; 9
	RETLW .63	; A
	RETLW .69	; B
	RETLW .75	; C
	RETLW .81	; D
	RETLW .87	; E
	RETLW .93	; F

;*********************************************************************************************;	
;					TRAJETO
; Quando chamada, esta funcao faz com que POSITION (posicao do motor) se iguale a TARGET
;*********************************************************************************************;
TRAJETO:
	CALL CALC ; Calcula trajetoria
	; Retorna em DIF a maneira otima de chegar a posicao final
MOVIMENTO:
	CALL MOVER
	; {	Modifica em PORTB somente os 4 bits que controlam o motor
	MOVWF VAR1 
	MOVF PORTB, W
	ANDLW B'00001111'
	IORWF VAR1, W
	MOVWF PORTB 
	; }
	CALL DELAY_PASSO ; Delay adicional entre passos
	
	MOVF DIF
	BTFSS STATUS, Z ; DIF = 0?
	GOTO MOVIMENTO	; Ainda nao...
	RETURN			; Sim

;*********************************************************************************************;
;				    CALCULA
; Retorna em DIF a maneira otima de chegar a posicao final
;*********************************************************************************************;
CALC:
	MOVF POSITION, W
	SUBWF TARGET, W
	MOVWF VAR1 ; VAR1 = TARGET - POSITION
	
	BTFSS VAR1, 7 ; VAR1 e' negativo?
	GOTO $+3
	COMF VAR1, W
	ADDLW .1 ; W = - VAR1
	
	SUBLW PASSOS_2 ; W = PASSOS/2 - |VAR1|
	
	BTFSC STATUS, C ; Deu borrow? 
	GOTO NORMAL ; Não
ALTERADO: ; Transicao  F <-- 0  ou  F --> 0
	MOVF VAR1, W
	BTFSS VAR1, 7
	GOTO $+3
	ADDLW PASSOS
	GOTO $+2
	ADDLW -PASSOS
	MOVWF DIF 
	RETURN
NORMAL:
	MOVF VAR1, W
	MOVWF DIF 
	RETURN
	
    ; DIF guarda a quantidade de passos que devera ser dada. 
    ; Caso seja negativo, estara em complemento 2

;*********************************************************************************************;
; 					MOVER
; Move um passo na direcao determinada por DIF
; Retorna em W o estado de energizacao das bobinas
; Atualiza POSITION e DIF
;*********************************************************************************************;
MOVER:
	MOVF DIF, F
	BTFSC STATUS, Z ; DIF é zero?
	GOTO TABELA_BOBINA ; Sim
	
	BTFSC DIF, 7 ; DIF é negativo?
	GOTO CELERA_ESQUERDA ; Sim

CELERA_DIREITA:
	DECF DIF
	
	INCF POSITION
	MOVLW PASSOS
	XORWF POSITION, W
	BTFSC STATUS, Z ; POSITION = PASSOS?
	CLRF POSITION ; Sim, Entao Zera POSITION!
	
	INCF BOBINA_8
	MOVLW .8
	XORWF BOBINA_8, W
	BTFSC STATUS, Z ; BOBINA_8 = 8?
	CLRF BOBINA_8 ; Sim, Entao Zera BOBINA_8
	GOTO TABELA_BOBINA
	
CELERA_ESQUERDA:
	INCF DIF
	
	MOVF POSITION
	BTFSS STATUS, Z ; POSITION = 0 ?
	GOTO $+3 ; Nao. So decrementa
	MOVLW PASSOS ; Sim. Reinicia POSITION e decrementa
	MOVWF POSITION
	DECF POSITION ; de 0 a 2*n-1

	MOVF BOBINA_8
	BTFSS STATUS, Z ; BOBINA_8 = 0 ?
	GOTO $+3 ; Nao. So decrementa
	MOVLW .8 ; Sim. Reinicia BOBINA_8 e decrementa
	MOVWF BOBINA_8
	DECF BOBINA_8 ; de 0 a 7

TABELA_BOBINA:
	MOVF BOBINA_8, W
	ADDWF PCL
	RETLW B'00010000' ; BOBINA_8 = 0
	RETLW B'00110000' ; BOBINA_8 = 1
	RETLW B'00100000' ; BOBINA_8 = 2
	RETLW B'01100000' ; BOBINA_8 = 3
	RETLW B'01000000' ; BOBINA_8 = 4
	RETLW B'11000000' ; BOBINA_8 = 5
	RETLW B'10000000' ; BOBINA_8 = 6
	RETLW B'10010000' ; BOBINA_8 = 7
	
;*********************************************************************************************;
;		Rotinas de DELAY
; DELAY_FLAG é o tempo de espera adicional quando o motor chega a uma posição determinada
; DELAT_PASSO é o tempo adicional de espera entre os passos para energizar as bobinas
;*********************************************************************************************;	
DELAY_FLAG:
			;2999995 cycles
	movlw	0x1A
	movwf	VAR1
	movlw	0x8B
	movwf	VAR2
	movlw	0x07
	movwf	VAR3
DELAY_FLAG_0
	decfsz	VAR1, f
	goto	$+2
	decfsz	VAR2, f
	goto	$+2
	decfsz	VAR3, f
	goto	DELAY_FLAG_0

			;1 cycle
	nop

			;4 cycles (including call)
	return
;*********************************************************************************************;	
DELAY_PASSO:
			;1693 cycles
	movlw	0x52
	movwf	VAR1
	movlw	0x02
	movwf	VAR2
DELAY_PASSO_0
	decfsz	VAR1, f
	goto	$+2
	decfsz	VAR2, f
	goto	DELAY_PASSO_0

			;3 cycles
	goto	$+1
	nop

			;4 cycles (including call)
	return
;*********************************************************************************************;
	
	END