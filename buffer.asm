; Buffer management

%out Entering buffer.asm

DATA_S segment public 'data'
	; Dimensione del buffer
	kBufSize EQU 80*25*3
	; buffer null terminated, non si sa mai
	textBuffer DB kBufSize dup(?),00h
	endOfBuffer DW offset textBuffer
	;puntatore all'inizio del testo visibile
	;inizialmente in cima al buffer
	viewPort DW offset textBuffer
	viewPortW DB ? ;lunghezza di una riga del viewport
	; "registro di stato" del buffer
	; bit 0 - EOF reached
	; bit 1 - End Of String reached
	bufStatus DB 00h
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

	mov endOfBuffer,offset textBuffer
	add endOfBuffer,AX ;sposto l'end-of-buffer e termino il buffer
	mov BX,endOfBuffer
	mov byte ptr [BX],00h
	
	mov BX,bufStatus
	cmp AX,CX ; Controllo se abbiamo raggiunto la fine del file
	je eofNotReached
	or BX,01h
	mov bufStatus,BX ;imposto il bit di EOF raggiunto
	ret

	eofNotReached:
	and BX,0FEh ;cancello il bit EOF
	mov bufStatus,BX
	ret

	lblReadError:
	mov exitCode,05h
	call QUIT_P
BUFFER_FILL_P endp

; Lo scopo di REFILL_P e' di riempire il buffer con nuovo contenuto dal file, 
; mantenendo pero' nel buffer la parte visibile (da viewport alla fine del buffer)
REFILL_P proc near

REFILL_P endp

; Scrolldown_p sposta il viewport di una riga
; se è possibile. 
SCROLLDOWN_P proc near
	; nel caso ci siano entrambi EOF and End Of Buffer non posso
	; fare scrolling
	mov BX,bufStatus
	test BX,01h
	jz tryScroll
	test BX,02h
	jnz dontScroll

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
	jnb lblFineBuffer
	mov viewPort,DI ;aggiorno il viewport
	pop ES
	ret
	
	dontScroll: ;Rimane tutto come prima
	ret
SCROLLDOWN_P endp

SCROLLUP_P proc near

SCROLLUP_P endp

CODE_S ends
