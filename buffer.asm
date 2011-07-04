; Buffer management

%out Entering buffer.asm

DATA_S segment public 'data'
	; lunghezza di un tab in caratteri
	kTabLen EQU 4
	; Dimensione del buffer
	kBufSize EQU 80*25*1
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
	; di quanti byte riempiamo il buffer tornando indietro
	rewindSize DW ? 
DATA_S ends

CODE_S segment public 'code'
	assume DS:DATA_S, CS:CODE_S, SS:STACK_S

;BUFFER_FILL_P riempie il buffer per la prima volta
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
	or BL,04h ; imposto il bit di SOF raggiunto (start of file)
	cmp AX,CX ; Controllo se abbiamo raggiunto la fine del file
	je eofNotReached
	or BL,01h ; imposto il bit di EOF raggiunto
	; dato che è la prima lettura, significa che anche
	; l'inizio del buffer corrisponde con l'inizio del file
	mov bufStatus,BL 
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
	; se REFILL_P è stata chiamata non è più start of file
	and BL,0FBh ; resetto SOF
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

; REWIND_P serve per caricare il buffer con il contenuto "precedente" nel file
REWIND_P proc near
	; interrogo il DOS per sapere il riferimento assoluto nel file
	mov AH,42h ;SEEK
	mov AL,01h ;dalla posizione attuale
	mov BX,fileHandle
	mov CX,00h ;parte alta dell'offset
	mov DX,00h ;parte bassa dell'offset
	int 21h 
	jc lblToPosError
	jmp afterPosQuery
	lblToPosError:
	jmp lblPosError
	afterPosQuery:

	; in DX:AX la posizione assoluta dall'inizio del file
	; mi sposto nel file al byte corrispondente al viewPort
	mov BX,endOfBuffer
	sub BX,viewPort ;in BX i byte "visibili"
	sub AX,BX
	sbb DX,0 ;in DX:AX la posizione del viewPort nel file

	; se la posizione assoluta è più grande di mezzo buffer
	; carico mezzo buffer, altrimenti tutti i byte
	; kBufSize è grande una word quindi
	mov BX,kBufSize/2 ;kBufSize deve essere pari
	test DX,DX ;se DX è non zero sicuramente possiamo leggere mezzo buffer
	jnz sizeFound
	cmp AX,BX 
	ja sizeFound ;abbiamo più dati di mezzo buffer
	; se ci sono pochi byte, ritorniamo indietro di quei pochi
	; e imposto lo status di SOF
	mov BX,AX ;in BX di quanti byte dobbiamo tornare indietro
	mov CL,bufStatus
	or CL,04h
	mov bufStatus,CL
	sizeFound:
	; spostiamo la posizione assoluta di quei BX bytes
	sub AX,BX
	sbb DX,0 ;in DX:AX la posizione da cui iniziare a leggere BX bytes
	
	; uso movsb per spostare i dati già presenti
	; in pratica i dati già esistenti slittano di BX bytes
	push ES
	push DS
	pop ES
	std
	mov DI,offset textBuffer+kBufSize-1 ;ultimo byte del buffer
	mov SI,offset textBuffer+kBufSize-1
	sub SI,BX 
	mov CX,kBufSize
	sub CX,BX ;devo copiare kBufSize-BX bytes
	muoviStringa:
	movsb
	dec CX
	jnz muoviStringa
	; repnz movsb
	cld
	pop ES
	
	push BX ;salvo il numero di caratteri!
	; spostamento DX:AX -> CX:DX
	mov CX,DX
	mov DX,AX ;nuovo offset
	mov AH,42h ;mi sposto indietro di BX bytes!!
	mov AL,00h 
	mov BX,fileHandle
	int 21h
	jc lblRewindReadErr

	pop BX ;ripristino numero caratteri!	
	; chiedo al DOS di caricare nella prima parte del buffer BX bytes
	mov AH,3Fh
	mov CX,BX
	mov BX,fileHandle
	mov DX,offset textBuffer
	int 21h
	jc lblRewindReadErr
	
	; aggiorno puntatori buffer
	mov BX,offset textBuffer
	add BX,AX
	mov viewPort,BX ;aggiorno viewPort
	mov endOfBuffer,offset textBuffer+kBufSize-1

	; aggiorno il puntatore del file
	mov DX,offset textBuffer+kBufSize-1
	sub DX,AX ;parte bassa dell'offset
	mov AH,42h ;spostamento  
	mov AL,01h ;dalla posizione attuale
	mov BX,fileHandle
	mov CX,00h ;parte alta dell'offset
	int 21h 
	
	;finito, ora si tenta lo scrollup
	ret


	lblPosError:
		mov exitCode,06h
		call QUIT_P
	lblRewindReadErr:
		mov exitCode,05h
		call QUIT_P	
REWIND_P endp

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
	; controlliamo se abbiamo passato l'origine
	cmp DI,offset textBuffer
	jb hitTop ;se si gestiamo l'evento
	test CX,CX ; uscito per CX=0? mi sono spostato di una riga intera?
	jz updateViewPort

	; Passo DUE
	; se il carattere che precede LF è CR saltiamolo
	cmp byte ptr [DI],0Dh
	jnz CRnotPresent
	dec DI
	; oltrepassata l'origine?
	cmp DI, offset textBuffer
	jb hitTop
	CRnotPresent:
	; Passo TRE
	; cerco LF per scrW caratteri, contando quante volte fallisco in DX
	xor DL,DL
	searchRowStart:
		mov CL,viewPortW
		repnz scasb
		cmp DI,offset textBuffer
		jb hitTopInSearch ; passata l'origine
		
		test CX,CX ;spostamento di una riga intera?
		jnz inizioRiga
		inc DL
	jmp searchRowStart
	
	hitTopInSearch:
	;come sempre se SOF allora scroll, altrimenti rifai tutto
	mov BL,bufStatus
	test BL,04h
	jz fillBackward
	mov DI,offset textBuffer
	test DL,DL ;la prima riga è corta
	jz updateViewPort
	reachRowinSearch:
		add DI,word ptr viewPortW
		dec DL
	jnz reachRowInSearch
	jmp updateViewPort

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
	;evento hitTop
	;ripristino il viewPort precedente se è SOF
	;altrimenti carico il pezzo precedente di file
	hitTop:
	mov BL,bufStatus
	test BL,04h
	jz fillBackward
	mov viewPort,offset textBuffer ; se è SOF
	mov DI,viewPort
	jmp outScrollUp ; viewPort=inizio del buffer ed esco
	fillBackward: ;sistemo il buffer
	call REWIND_P
	call SCROLLUP_P ;e ritento lo scroll.
	;jmp outScrollUp
	outScrollUp:
	pop ES
	cld
	ret
SCROLLUP_P endp

CODE_S ends
