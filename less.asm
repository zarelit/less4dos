; Main file

; Inclusione delle varie parti del codice
include box.asm
include user.asm
include buffer.asm

; Global stack
STACK_S segment stack
	DB 256 dup('STACK:-)')
STACK_S ends

; Global data
DATA_S segment public 'data'
	kVideoMode EQU 03h ;video mode 80x25
	dosVideoMode DB 0FFh	 ; modo video DOS
	exitCode DB 0	;vedi Codici di uscita
	fileName DB 256 dup(?) ; nome del file di testo da aprire
	fileHandler DW 0000h ;handler restituito dal S.O.
DATA_S ends

; Main program
CODE_S segment public 'code'
	assume CS:CODE_S, DS:DATA_S, SS:STACK_S

MAIN_P proc near
	; Memorizzo il nome file passato come argomento al programma
	; Uso le funzioni di stringa
	mov AX, seg DATA_S
	mov ES,AX
	cld
	mov DI,offset fileName
	mov SI,0082h ; la command line parte da 81h, il nome file da 82h
	mov BX,0080h ; il numero di caratteri della command line
	mov CX,[BX]
	xor CH,CH
	;cmp CX,0
	test CX,CX ; se nessun parametro è stato passato: errore file
	jz lblFileError
	dec CX ; ignoro lo spazio all'inizio. Copio un char di meno
	repnz movsb ; copio la stringa
	mov AL,00h ; rendo ASCIIZ la stringa
	stosb

	; load DS with the right value
	mov AX,seg DATA_S
	mov DS,AX

	; Verifichiamo se il file esiste ed è apribile
	mov AH,3Dh ;apri file <2GiB
	mov AL,00h ;apri in sola lettura
	mov DX,offset fileName
	int 21h
	jc lblFileError
	
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

	
	; Attesa risposta utente
	userloop:
	call USER_P
	jmp userloop

	lblFileError:
		mov exitCode,03h
		call QUIT_P

MAIN_P endp

CODE_S ends

; Entry point
end MAIN_P

; Codici di uscita
; 0 - Nessun errore riscontrato
; 1 - Box da disegnare troppo largo
; 2 - Box da disegnare troppo lungo
; 3 - Impossibile aprire il file specificato
