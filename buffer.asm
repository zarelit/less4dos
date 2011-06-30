; Buffer management

%out Entering buffer.asm

DATA_S segment public 'data'
	; Dimensione del buffer
	kBufSize EQU 80*25*3
	; buffer null terminated, non si sa mai
	textBuffer DB kBufSize dup(?)
	endOfBuffer DB 00h
	;puntatore all'inizio del testo visibile
	;inizialmente in cima al buffer
	viewPort DW offset textBuffer
	viewPortW DB ? ;lunghezza di una riga del viewport
DATA_S ends

CODE_S segment public 'code'
	assume DS:DATA_S, CS:CODE_S, SS:STACK_S

;BUFFER_FILL_P riempie inizialmente il buffer
BUFFER_FILL_P proc near
	mov AH,3Fh
	mov BX,fileHandle
	mov CX,kBufSize
	mov DX,offset textBuffer
	int 21h
	ret
BUFFER_FILL_P endp

; Scrolldown_p sposta il viewport di una riga
; se è possibile. Altrimenti prova a riempire il buffer
SCROLLDOWN_P proc near
	; cero l'inizio della prossima riga
	; ci si ferma incontrando LF oppure dopo viewPortW caratteri
	mov CL,viewPortW
	xor CH,CH
	mov AL,0Ah ; LF
	push ES ;scasb vuole la stringa in ES:DI ma in ES abbiam la memoria video
	mov BX,DS
	mov ES,BX
	mov DI,viewPort
	repnz scasb
	mov viewPort,DI
	pop ES
	ret
SCROLLDOWN_P endp

CODE_S ends
