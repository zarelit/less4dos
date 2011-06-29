; Main file

; Inclusione delle varie parti del codice
include box.asm

; Global stack
STACK_S segment stack
	DB 256 dup('STACK:-)')
STACK_S ends

; Global data
DATA_S segment public 'data'
	exitCode DB 0	;vedi Codici di uscita
DATA_S ends

; Main program
CODE_S segment public 'code'
	assume CS:CODE_S, DS:DATA_S, SS:STACK_S

MAIN_P proc near
	;Uscita al DOS
	mov AH,4Ch
	mov AL,exitCode
	int 21h
MAIN_P endp

CODE_S ends

; Entry point
end MAIN_P

; Codici di uscita
; 0 - Nessun errore riscontrato
