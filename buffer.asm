; Buffer management

DATA_S segment public 'data'
	; Dimensione del buffer
	kBufSize EQU 80*25*3
	; buffer null terminated, non si sa mai
	textBuffer DB kBufSize dup(?)
	endOfBuffer DB 00h
	;puntatore all'inizio del testo visibile
	;inizialmente in cima al buffer
	viewPort DB offset textBuffer
DATA_S ends

CODE_S segment public 'code'
	assume DS:DATA_S, CS:CODE_S, SS:STACK_S

BUFFER_FILL_P proc near
	mov AH,3Fh
	mov BX,fileHandle
	mov CX,kBufSize
	mov DX,offset textBuffer
	int 21h
	ret
BUFFER_FILL_P endp

CODE_S ends
