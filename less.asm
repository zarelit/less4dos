; David Costa <david@zarel.net>
; Progetto per Calcolatori 2
; "less", un visualizzatore di file di testo

; Main file

%out Entering less.asm
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
	fileHandle DW 0000h ;handler restituito dal S.O.
	fileSizeHigh DW ? ;dimensione del file di testo
	fileSizeLow DW ?

	outerH DB 24		;parametri per cambiare la presenza
	outerW DB 80            ;del fullscreen
	framePresence DB 01h 

	scrollUpCount DW 00h
	scrollDownCount DW 00h ;automatismi scroll up/down
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
	jz lblToNoCmdLine
	jmp skipNoCmdLine
	lblToNoCmdLine:
	jmp lblNoCmdLine
	skipNoCmdLine:
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
	jc lblToFileError
	jmp skipFileError
	lblToFileError:
	jmp lblFileError
	skipFileError:

	mov fileHandle,AX
	call GETFILESIZE_P
	
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

	; Disegno il menu
	call PRINT_MENU_P
	; Riempio il buffer ed entro nel ciclo eventi
	call BUFFER_FILL_P
	lblEventLoop:
		;l'origine è sempre in alto-dx
		mov DX,0000h
		;le dimensioni variano a seconda del fullscreen o meno
		mov AH,outerH
		mov AL,outerW
		mov CL,framePresence
		mov SI,viewPort
		call BOX_P
		jz checkRefill
		mov lastDrawn,SI
		;se BOX_P ritorna non zero è END-OF-BOX 
		mov BL,bufStatus
		and BL,0FDh ; clear end of buffer
		mov bufStatus,BL

		;ci sono righe da scorrere?
		autoScrollDown:
		mov CX,scrollDownCount
		test CX,CX
		jz autoScrollUp
		dec scrollDownCount
		call SCROLLDOWN_P
		jmp lblEventLoop
		
		autoScrollUp:
		mov CX,scrollUpCount
		test CX,CX
		jz lblWaitUser
		dec scrollUpCount
		call SCROLLUP_P
		jmp lblEventLoop

		; Attesa risposta utente
		lblWaitUser:
		call POSITION_P
		call USER_P
	jmp lblEventLoop
	
	; terminata la stringa. Dobbiamo proseguire nel file?
	; Se si ricarica e ridisegna
	; Se no attendi azione utente
	checkRefill:
		;BOX_P ci ha detto che ha finito la stringa.
		;Quindi è End of buffer
		mov BL,bufStatus
		or BL,02h ;set end-of-buffer
		mov bufStatus,BL
		test BL,01h ;check for EOF
		;jnz lblWaitUser ;no - il file è finito
		jnz autoScrollDown
		call REFILL_P
	jmp lblEventLoop

	lblNoCmdLine:
		mov AX,seg DATA_S
		mov DS,AX
		mov exitCode,04h
		call QUIT_P
	lblFileError:
		mov AX, seg DATA_S
		mov DS,AX
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
; 4 - Nessun file fornito sulla riga di comando.
; 5 - Errore nella lettura del file.
