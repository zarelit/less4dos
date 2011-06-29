; Main file

; Inclusione delle varie parti del codice
include box.asm
include user.asm

; Global stack
STACK_S segment stack
	DB 256 dup('STACK:-)')
STACK_S ends

; Global data
DATA_S segment public 'data'
	kVideoMode EQU 03h ;video mode 80x25
	dosVideoMode DB ?	; modo video DOS
	exitCode DB 0	;vedi Codici di uscita

	dummyText DB 'This is a real dummy Test',0Dh,0Ah,'On two rows.',00h
DATA_S ends

; Main program
CODE_S segment public 'code'
	assume CS:CODE_S, DS:DATA_S, SS:STACK_S

MAIN_P proc near
	; load DS with the right value
	mov AX,seg DATA_S
	mov DS,AX

	; Salvo il modo video corrente
	; (chiamata BIOS getVideoMode)
	mov AH,0Fh
	int 10h
	mov dosVideoMode,AL

	; Imposto il modo testo 80x25 colori
	; (chiamata BIOS setVideoMode)
	mov AH,00h
	mov AL,kVideoMode
	int 10h

	; Elimino la noiosa presenza del cursore
	mov AH,01h
	mov CX,2607h
	int 10h
	
	; Due box di test
	mov SI,offset dummyText
	mov DX,0304h
	mov AX,0506h
	mov CX,0001h
	call BOX_P

	mov SI,offset dummyText
	mov DX,1405h
	mov AX,0320h
	mov CX,0001h
	call BOX_P

	mov SI,offset dummyText
	mov DX,0101h
	mov AX,0130h
	mov CX,0000h
	call BOX_P
	
	; Attesa risposta utente
	userloop:
	call USER_P
	jmp userloop

MAIN_P endp

CODE_S ends

; Entry point
end MAIN_P

; Codici di uscita
; 0 - Nessun errore riscontrato
