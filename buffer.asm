; David Costa <david@zarel.net>
; Progetto per Calcolatori 2
; "less", un visualizzatore di file di testo

; Buffer management

%out Entering buffer.asm

DATA_S segment public 'data'
	; Dimensione del buffer
	kBufSize EQU 80*25*1 ;4E20 bytes, non sfora il segmento
	; buffer null terminated, non si sa mai
	textBuffer DB kBufSize dup(?),00h
	endOfBuffer DW offset textBuffer
	;puntatore all'inizio del testo visibile
	;inizialmente in cima al buffer
	viewPort DW offset textBuffer
	viewPortW DB 78 ;lunghezza di una riga del viewport
		  DB 00h ;nel caso volessi usarlo come word
	viewPortH DB 22 ;altezza del viewport
		  DB 00h
	; "registro di stato" del buffer
	; bit 0 - EOF reached
	; bit 1 - End Of String reached
	bufStatus DB 00h
	; di quanti byte riempiamo il buffer tornando indietro
	rewindSize DW ? 
	physCurLow DW ?
	physCurHigh DW ?
	tempBufLen DW ?
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
	; dato che BOX_P è uscita con end-of-string in SI c'è l'offset
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
	; Alla fine viewPort deve puntare a circa metà buffer, allo stesso carattere
	; a cui puntava prima della chiamata.
	; endOfBuffer punterà alla fine effettiva del buffer e il puntatore fisico del file
	; deve puntare al carattere che seguirebbe l'ultimo del buffer

	; Otteniamo la posizione fisica all'interno del file effettuando uno
	; spostamento relativo nullo
	mov AH,42h ; operazione di seek
	mov AL,01h ; spostamento relativo alla posizione attuale
	mov BX,fileHandle
	mov CX,00h ; l'offset si trova in CX:DX
	mov DX,00h
	int 21h
	; se il carry non è settato abbiamo la posizione in DX:AX
	jc lblToGetPosError
	jmp skipGetPosError
	lblToGetPosError:
	jmp lblGetPosError
	skipGetPosError: ;selva di jump e label per limitazione salti short
	
	; salviamo il puntatore fisico (non si sa mai)
	mov physCurHigh,DX
	mov physCurLow,AX

	; valutiamo di quanti byte possiamo shiftare il buffer
	; al massimo lo scrolling è di kBufSize/2 in modo da avere
	; qualche riga disponibile in entrambe le direzioni di
	; scorrimento
	; kBufSize è sempre utilizzato come quantità a 16 bit
	; (deve stare comunque dentro il segmento dati)
	; La posizione assoluta in DX:AX è anche il numero di byte
	; già letti
	mov BX,kBufSize/2
	test DX,DX ;DX non zero=abbiamo più di 64K disponibili
	jnz skipResize ;saltiamo il ridimensionamento
	cmp AX,kBufSize/2 ;controlliamo di avere kBufSize/2 bytes da poter caricare
	jnb skipResize ;se abbiamo esattamente kBufSize/2 o più non ridimensioniamo
	mov BX,AX ;possiamo caricare solo BX bytes
	; se carichiamo meno di kBufSize/2 è perchè abbiamo raggiunto l'inizio del file
	mov CL,bufStatus
	or CL,04h ;setto SOF
	mov bufStatus,CL

	skipResize:
	;BX=numero di byte di rewind
	mov rewindSize,BX
	
	; Lo spostamento è di BX bytes dopo aver allineato il puntatore fisico con
	; il viewPort
	; Mi sposto indietro di endOfBuffer-viewPort
	mov CX,physCurHigh
	mov DX,physCurLow
	; in CX:DX il punt.fisico che ora sposto indietro
	mov BX,endOfBuffer
	sub BX,viewPort
	mov tempBufLen,BX ;salvo la lunghezza del buffer (non si sa mai)
	; ora decremento il puntatore fisico di BX
	sub DX,BX
	sbb CX,0 ;considero un eventuale prestito	
	; A questo punto CX:DX è allineato con viewPort
	; Mi devo spostare indietro ancora di rewindSize caratteri
	mov AX,rewindSize
	sub DX,AX
	sbb CX,0 ;considero sempre un eventuale prestito
	; Ora CX:DX punta esattamente a quello che andrà inserito
	; all'inizio del buffer
	mov AH,42h ;seek
	mov AL,00h ;dall'origine
	mov BX,fileHandle
	int 21h	
	jc lblToGetPosError
	; A questo punto il file è pronto per essere letto.
	; Ma sovrascriverebbe i dati già esistenti tra viewPort e endOfBuffer
	; dato che rewind_p viene chiamata da scrollup_p, ES punta già al segmento dati.
	; Si distinguono due casi, quello in cui l'inserimento di nuovi dati non comporta
	; lo slittamento di dati fuori dal buffer e quello in cui dei dati vengono persi
	; Basta controllare se tempBufLen+rewindSize è minore di kBufSize
	mov BX,rewindSize
	add BX,tempBufLen
	cmp BX,kBufSize ;puntatore alla fine in memoria del buffer
	jb inPlace
	; scarto caratteri 
	nonInPlace:
		std
		mov SI,endOfBuffer
		dec SI ;viene usato il terminatore di fine buffer
		mov CX,BX
		sub CX,kBufSize ;numero di caratteri effettivamente scartati

		; sistemo il viewPort
		mov AX, viewPort
		add AX, rewindSize
		sub AX,CX
		dec AX
		mov viewPort, AX

		sub SI,CX ;SI è OK
		mov DI,offset textBuffer+kBufSize
		dec DI
		mov BX,tempBufLen
		sub BX,CX
		xchg BX,CX
		; salvo sullo stack di quanto deve spostarsi il puntatore fisico
		push CX
		repnz movsb
		;aggiorno l'end of buffer
		mov endOfBuffer,offset textBuffer+kBufSize
		cld
		jmp fillTopBuffer
	; non scarto caratteri
	inPlace:
		; BX=nuovo endOfBuffer
		std ;copia al contrario, evita la ripetizione dei dati per overlap
		add BX,offset textBuffer
		mov SI,endOfBuffer
		mov DI,BX
		; copio i dati, sono tempBufLen bytes + 1 terminatore
		mov CX,tempBufLen
		inc CX
		repnz movsb
		cld
		; aggiorno l'endOfBuffer
		mov endOfBuffer,BX
		; salvo sullo stack di quanto deve spostarsi il puntatore fisico
		mov AX,tempBufLen
		push AX
		; sistemo il viewPort
		mov AX, viewPort
		add AX, rewindSize
		mov viewPort, AX
		jmp fillTopBuffer
	fillTopBuffer:
		;riempio la prima parte del buffer
		mov AH,3Fh ;lettura da file
		mov BX,fileHandle
		mov DX,offset TextBuffer
		mov CX,rewindSize
		int 21h
		jc lblGetPosError
		
		;sposto il puntatore fisico al byte che corrisponde a endOfBuffer
		mov AH,42h ;seek
		mov AL,01h ; dalla posizione attuale
		pop DX ;parte bassa dell'offset
		mov CX,0000h ;alta dell'offset
		mov BX,fileHandle
		int 21h
		
		ret
	lblGetPosError:
		mov exitCode,06h
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

; Scrolla di una pagina (secondo le dimensioni del box)
PAGEDOWN_P proc near
	mov CX,word ptr viewPortH
	mov scrollDownCount,CX
	ret
PAGEDOWN_P endp

; Scrolla di una pagina verso l'alto (secondo le dimensioni del box)
PAGEUP_P proc near
	mov CX,word ptr viewPortH
	mov scrollUpCount,CX
	ret
PAGEUP_P endp

CODE_S ends
