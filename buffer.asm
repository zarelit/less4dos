; Buffer management

%out Entering buffer.asm

DATA_S segment public 'data'
	; lunghezza di un tab in caratteri
	kTabLen EQU 4

	; Dimensione del buffer
	kBufSize EQU 80*25*3
	; buffer null terminated, non si sa mai
	textBuffer DB kBufSize dup(?),00h
	endOfBuffer DW offset textBuffer
	;puntatore all'inizio del testo visibile
	;inizialmente in cima al buffer
	viewPort DW offset textBuffer
	viewPortW DB ? ;lunghezza di una riga del viewport
		  DB 00h ;nel caso volessi usarlo come word
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
	
	mov BL,bufStatus
	cmp AX,CX ; Controllo se abbiamo raggiunto la fine del file
	je eofNotReached
	or BL,01h
	mov bufStatus,BL ;imposto il bit di EOF raggiunto
	ret

	eofNotReached:
	and BL,0FEh ;cancello il bit EOF
	mov bufStatus,BL
	ret

	lblReadError:
	mov exitCode,05h
	call QUIT_P
BUFFER_FILL_P endp

; Lo scopo di REFILL_P e' di riempire il buffer con nuovo contenuto dal file, 
; mantenendo pero' nel buffer la parte visibile (da viewport alla fine del buffer)
REFILL_P proc near
	; prima parte, copio da viewPort alla fine della stringa
	; e sposto viewPort in testa
	; dato che BOX_P è uscita con end-of-string in DI c'è l'offset
	; della fine della stringa, pertanto
	; i caratteri da copiare sono SI-viewPort
	dec SI
	mov CX,SI
	sub CX,viewPort
	push CX ;questo conteggio ci serve dopo per sapere quanto buffer abbiamo occupato
	;uso movsb che sposta da ds:si a es:di
	push ES ;salvo ES alla memoria video
	push DS 
	pop ES ;copio DS in ES
	; le aree di memoria non possono essere intersecate
	mov SI,viewPort
	mov DI,offset textBuffer
	repnz movsb
	pop ES ;ripristino ES alla memoria video
	mov viewPort,offset textBuffer
	mov endOfBuffer,DI

	;riempiamo il resto del buffer con nuovo contenuto dal file
	pop BX ;ripristiniamo il conteggio dei caratteri
	mov CX,kBufSize
	sub CX,BX ;in CX numero di caratteri che possiamo leggere dal file
	mov AH,3Fh
	mov BX,fileHandle 
	mov DX,endOfBuffer ;iniziamo a scrivere da dove avevamo interrotto
	int 21h
	jc lblRefillError
	
	add endOfBuffer,AX ;sposto l'end-of-buffer e termino il buffer
	mov BX,endOfBuffer
	mov byte ptr [BX],00h
	
	mov BL,bufStatus
	cmp AX,CX ; Controllo se abbiamo raggiunto la fine del file
	je refillEofNotReached
	or BL,01h
	mov bufStatus,BL ;imposto il bit di EOF raggiunto
	ret

	refillEofNotReached:
	and BL,0FEh ;cancello il bit EOF
	mov bufStatus,BL
	ret
	
	lblRefillError:
		mov exitCode,05h
		call QUIT_P
REFILL_P endp

; Scrolldown_p sposta il viewport di una riga
; se è possibile. 
SCROLLDOWN_P proc near
	; nel caso ci siano entrambi EOF and End Of Buffer non posso
	; fare scrolling
	mov BL,bufStatus
	test BL,01h
	jz tryScroll
	test BL,02h
	jnz dontScroll

	tryScroll:
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
	mov viewPort,DI ;aggiorno il viewport
	pop ES
	ret
	
	dontScroll: ;Rimane tutto come prima
	ret
SCROLLDOWN_P endp

; SCROLLUP_P fa lo scroll verso l'alto di una riga
SCROLLUP_P proc near
	;procedura di base
	;SE si esce dal buffer subito evento hitTop
	;1) cerco di tornare indietro di viewPortW caratteri. Se non incontro LF, mi sposto. Se lo incontro
	;2) mi sposto all'ultimo carattere stampabile (prima di 0D) 
	;3) cerco LF per scrW caratteri, contando il numero di volte. (N)
	;4) quando lo incontro mi sposto al carattere successivo (primo stampabile)
	;5) mi sposto di N volte scrW
	push ES ;salvo ES
	push DS
	pop ES ;copio DS in ES
	std ;si cerca all'indietro

	; Passo UNO
	mov AL,0Ah ;cerco LF
	mov DI,viewPort ; a partire dall'origine
	mov CL,viewPortW ;per scrW
	xor CH,CH
	repnz scasb
	test CX,CX ; uscito per CX=0?
	jz updateViewPort

	; Passo DUE
	; se il carattere che precede LF è CR saltiamolo
	cmp byte ptr [DI],0Dh
	jnz CRnotPresent
	dec DI
	CRnotPresent:
	
	; Passo TRE
	; cerco LF per scrW caratteri, contando quante volte fallisco in DX
	xor DL,DL
	searchRowStart:
		mov CL,viewPortW
		repnz scasb
		test CX,CX
		jnz inizioRiga
		inc DL
	jmp searchRowStart

	inizioRiga: ;siamo sul carattere che precede LF della riga precedente
	inc DI
	inc DI
	mov CL,DL ;ci spostiamo di tante righe quanti i fallimenti
	reachRow:	
	add DI,word ptr viewPortW
	dec CX
	jnz reachRow
	
	updateViewPort:
	mov viewPort,DI
	jmp outScrollUp
	;evento hitTop - ripristino il viewport precedente
	hitTop:
	mov DI,viewPort

	outScrollUp:
	pop ES
	cld
	ret
SCROLLUP_P endp

CODE_S ends
