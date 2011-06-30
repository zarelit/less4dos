; Buffer management

%out Entering buffer.asm

DATA_S segment public 'data'
	; Dimensione del buffer
	kBufSize EQU 80*25*3
	; buffer null terminated, non si sa mai
	textBuffer DB kBufSize dup(?),00h
	endOfBuffer DW offset textBuffer+1
	;puntatore all'inizio del testo visibile
	;inizialmente in cima al buffer
	viewPort DW offset textBuffer
	viewPortW DB ? ;lunghezza di una riga del viewport
DATA_S ends

CODE_S segment public 'code'
	assume DS:DATA_S, CS:CODE_S, SS:STACK_S

;BUFFER_FILL_P riempie il buffer continuando la lettura del file
BUFFER_FILL_P proc near
	;leggo kBufSize caratteri dal file
	;(in avanti)
	mov AH,3Fh
	mov BX,fileHandle
	mov CX,kBufSize
	mov DX,offset textBuffer
	int 21h
	; controllo quanti caratteri ho letto e imposto
	; l'end of buffer di conseguenza
	jc lblReadError
	add endOfBuffer,AX ;sposto l'end-of-buffer e termino il buffer
	mov BX,endOfBuffer
	mov byte ptr [BX],00h
	ret

	lblReadError:
	mov exitCode,05h
	call QUIT_P
BUFFER_FILL_P endp

; Scrolldown_p sposta il viewport di una riga
; se è possibile. Altrimenti prova a riempire il buffer
SCROLLDOWN_P proc near
	; cerco l'inizio della prossima riga
	; ci si ferma incontrando LF oppure dopo viewPortW caratteri
	mov CL,viewPortW
	xor CH,CH
	mov AL,0Ah ; LF
	push ES ;scasb vuole la stringa in ES:DI ma in ES abbiam la memoria video
	mov BX,DS
	mov ES,BX
	mov DI,viewPort
	repnz scasb
	; Non scrolliamo se abbiamo superato la validità del buffer.
	cmp DI,endOfBuffer
	ja nonscrolldown
	mov viewPort,DI ;aggiorno il viewport
	pop ES
	ret
	nonscrolldown:
	mov DI,viewPort ;ritorno al DI originale
	pop ES
	ret
SCROLLDOWN_P endp

SCROLLUP_P proc near

SCROLLUP_P endp

CODE_S ends