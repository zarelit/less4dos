; Progetto per l'esame di Calcolatori 2
; David Costa

STACK_S segment stack
	DB 256 dup('STACK:-)') ;Ogni ripetizione occupa 8 byte (4 word)
STACK_S ends

DATA_S segment 'data'
	;Opzioni
	videoMode EQU 03h	;modo video 80x25
	scrCols	EQU 80		;|coerente con videoMode
	scrRows EQU 25		;|coerente con videoMode
	scrWidth EQU scrCols*2
	kPage	EQU 00h		;pagina di testo di default
	kSegVideo EQU 0B800h	;segmento video. Lo 0 davanti al numero è necessario a MASM
	
	;Valori di uscita da FRAME_P 
	kOk	  EQU 00h	;box disegnato
	kErrLarge EQU 01h	;box troppo largo
	kErrLong  EQU 02h	;box troppo lungo

	;variabili globali e di MAIN_P
	oldMode	DB ?	;Modo video prima dell'ingresso nel programma
	;testText DB 'Una interessante stringa che non va a capo',0h
	testText DB "Norma Talmadge (Jersey City, 26 maggio 1893 - Las Vegas, 24 dicembre 1957) e' stata un'attrice"
		DB " e produttrice cinematografica statunitense dell'epoca del muto.",0Dh,0Ah
		DB "La Talmadge fu regina degli incassi al botteghino per piu' di un decennio e la sua carriera "
		DB "raggiunse il culmine all'inizio degli anni venti, quando entro' nella lista dei divi piu' popolari"
		DB " degli schermi statunitensi[1].",0Dh,0Ah,"Il suo film di maggior successo fu Smilin' Through"
		DB " (1922)[2], ma ottenne autentici trionfi, insieme al regista Frank Borzage, con Secrets (1924) "
		DB "e The Lady (1925). Anche le sue sorelle minori Constance e Natalie furono delle stelle del cinema."
		DB " Sposo' il miliardario produttore Joseph Schenck con il quale in seguito fondo' con successo una"
		DB " compagnia di produzione. Dopo aver raggiunto la fama grazie ai film girati sulla costa "
		DB "occidentale, nel 1922 si trasferi' a Hollywood.",0
	txtShortGuide DB '(Q)uit',0

	;variabili usate da FRAME_P e TEXT_P
	frameW DB ?	;Larghezza
	frameH DB ?	;Altezza
	internW DW ?	;numero trattini orizzontali
	internH DW ?	;numero trattini verticali
	rowPointer DW ?	;indirizzo inizio riga corrente
	rowEnd	DW ?	;indirizzo fine riga corrente
	boxEnd	DW ?	;indirizzo dell'ultimo carattere del box
	boxStart DW ?

	;buffer dati del file da leggere e puntatori
	inputFilename DB 'sonetti_.txt', 00h
	inputFileHandle DW ?
	kBufferSize EQU 4096 ;bytes. Lo schermo 80x25 ne contiene 2000.
	startPointer DW [textBuffer]
	textBuffer DB kBufferSize dup(?), 00h ;buffer dati da 1KiB, _terminato_
	
	;stringhe e variabili di debug.
	IFDEF VERBOSE
		newLine DB 0Dh,0Ah
		msgNoLog   DB 'Impossibile creare il file di log. uscita.$'
		msgTooLarge DB 'Box richiesto troppo largo.$'
		msgTooLong DB 'Box richiesto troppo lungo.$'
		msgChgMode DB 'Modo video cambiato in ',videoMode+'0','h.$'
		msgMoveCur DB 'Muovo il cursore in (riga,colonna) ('
		curRow	DW ?
			DB ','
		curCol  DW ?
			DB ')$'
		msgFramepExit DB 'Esco da FRAME_P. con stato '
		exitStatus    DW ? 
			      DB '$'
		msgCallFrameP DB 'Chiamo FRAME_P da (riga,colonna) ('
		callDH DW ?
		       DB ','
		callDL DW ?
		       DB ') e dimensioni ('
		callAH DW ? 
		       DB ','
		callAL DW ?
		       DB ')$'
		logFileName DB 'lesslog.txt',0
		logHandle DW ?
		msgScanCode DB 'Premuto il tasto con scancode '
		pressedScancode DW ?
				DB '$'

	ENDIF
DATA_S ends

;Direttiva sul processore. La CPU di default (8086) non implementa
;alcune istruzioni tra cui PUSHA e POPA. L'80186 ancora non implementa
;i salti condizionati e near.
.186

CODE_S segment para 'code'
	;Controllo dei segmenti
	assume CS:CODE_S, DS:DATA_S, SS:STACK_S
	
	;Punto d'ingresso.
	MAIN_P proc near
		;Imposto il DS, ora contiene l'indirizzo del PSP
		mov AX, seg DATA_S
		mov DS, AX
		
		IFDEF VERBOSE
			call DEBUG_INIT_P
		ENDIF

		;Salvo il modo video corrente
		mov AH,0Fh	;Video-mode query
		int 10h		;il video mode in AL
		mov oldMode,AL
		
		;Imposto l'80x25
		;02h->16 grigio, 03h->colori
		mov AX,videoMode
		int 10h
		IFDEF VERBOSE
			;stampo conferma cambio modo
			mov SI,offset msgChgMode
			call DEBUG_P
		ENDIF		

		;Apro il file di input 
		call OPENFILE_P

		;Leggo il contenuto del file e riempio il buffer.
		mov AH,3Fh
		mov BX,inputFileHandle
		mov CX,kBufferSize
		mov DX,offset textBuffer
		int 21h
		
		;Disegna breve guida
		mov DX,1800h
		mov AX,0150h
		mov SI,offset txtShortGuide
		clc
		call BOX_P
		
		;Programma inizializzato, ciclo eventi
		lblEventLoop:
			;Disegno la pagina
			mov AH,scrRows-1
			mov AL,scrCols
			mov DX,0000h
			;mov SI,offset textBuffer
			mov SI,[startPointer]
			stc
			call BOX_P

			;Attendo un'azione dall'utente
			call USER_P
		jmp lblEventLoop

		lblQuitProgram:

		;Chiudo il file di input
		call CLOSEFILE_P

		;Ripristino il modo video precedente
		mov AH,00h	;Video-mode set
		mov AL,oldMode
		int 10h

		;Esco correttamente al dos
		IFDEF VERBOSE
			push SI
			call DEBUG_END_P
			pop SI
		ENDIF
		;AH=4C, AL=valore ritorno
		mov AX, 4C00h
		int 21h
	MAIN_P endp
	
	;USER_P attende la pressione di un tasto e chiama le routine corrispondenti
	;all'azione scelta.
	USER_P proc near
		push AX
		mov AH,00h
		int 16h	;attendo la pressione di un tasto
		IFDEF VERBOSE
			push SI
			push AX
			xchg AL,AH
			call HEX2ASCII
			mov pressedScancode,AX
			mov SI,offset msgScancode
			call DEBUG_P
			pop AX
			pop SI
		ENDIF
		cmp AL,'Q'
		je quitChoice
		cmp AL,'q'
		je quitChoice  ;Tasti di uscita
		cmp AH,50h
		je scrollDown	;Freccia giù
		jmp quitUserP
		
		;da qui in poi routine delle scelte
		quitchoice:	
			jmp lblQuitProgram
		scrollDown:
			call SCROLLDOWN_P
			jmp quitUserP
		quitUserP:
		pop AX
		ret
	USER_P endp	
	
	;SCROLLDOWN_P fa scorrere il testo di una riga verso la fine del file
	SCROLLDOWN_P proc near
		;cerco l'inizio della prossima riga
		;ci si ferma incontrando LF oppure dopo scrCols caratteri
		mov CX,scrCols
		mov AL,0Ah
		push ES ;scasb vuole la stringa in ES:DI, ma in ES abbiamo la memoria video
		mov BX,DS
		mov ES,BX ;ES=segmento buffer dati
		mov DI,startPointer
		cld
		repnz scasb
		mov startPointer,DI
		pop ES
		ret
	SCROLLDOWN_P endp

	;OPENFILE_P apre il file specificato (ora nelle variabili, hardcoded)
	;in caso di errore, esce dal programma
	OPENFILE_P proc near
		;mov AH,3Dh ;open file
		;mov AL,00h ;read only 
		mov AX,3D00h
		mov DX,offset inputFilename
		int 21h
		jc lblOpenFailed
		mov inputFileHandle,AX
		ret
		lblOpenFailed:
		jmp lblQuitProgram
	OPENFILE_P endp
	
	;CLOSEFILE_P chiude il file di input
	CLOSEFILE_P proc near
		mov AH,3Eh
		mov BX,inputFileHandle
	 	int 21h
		;anche se ci sono errori si uscirebbe dal programma.
		;ma il programma è già in fase di uscita
		ret
	CLOSEFILE_P endp
	
	;FRAME_P disegna cornici.  
	;Parametri:
	;	DH=Y DL=X, AH=H, AL=W
	FRAME_P proc near
		;non necessito di rientranza quindi NON setto uno stack frame
		;uso le variabili globali di DATA_S		

		;Memorizzo le dimensioni del box
		mov word ptr frameW,AX

		;controllo se la dimensione rientra nello schermo
		mov BX,DX
		add BH,AH
		add BL,AL	;calcolo la posizione dell'ultimo punto
		dec BL		;decremento in quanto la dimensione è
		dec BH		;comprensiva dell'ultima riga/colonna

		cmp BH,scrRows-1 ;confronto con il bordo schermo
		ja toLongError
		cmp BL,scrCols-1
		ja toLargeError
		jmp toNormalPath
		toLongError:
			jmp lblTooLong
		toLargeError:
			jmp lblTooLarge
		toNormalPath:

		;Faccio puntare l'extra segment alla memoria video.
		mov BX,kSegVideo
		mov ES,BX
		
		;spostamento all'origine del box
		;evito la moltiplicazione per 80 facendo somme di shift
		xor BH,BH
		mov BL,DH	;numero di righe in BX
		mov CL,04h
		shl BX,CL	;righe*16 in BX
		mov CX,BX	
		shl CX,1	
		shl CX,1	;righe*64 in CX
		add BX,CX	;righe*80 in BX
		
		xor DH,DH
		;mov SI,DX	;LEA vuole base registers. Uso SI per la colonna
		;lea DI,[SI][BX] ;in DI l'indirizzo di origine.
		mov DI,DX
		add DI,BX
		shl DI,1	;DUE byte, uno per carattere, uno per attributi
		mov rowPointer,DI
		;stampa angolo alto-sx
		;mov ES:[DI],byte ptr '/'
		;inc DI ;inc DI ;ciclo stampa bordo superiore
		cld		;I caratteri si trovano per indirizzi crescenti
		mov AL,'/'
		mov AH,07h	;attributo default bianco su nero
		stosw
		xor CH,CH
		mov CL,frameW
		dec CX
		dec CX	;in CX numero di trattini bordo superiore
		;push CX	;salvo. è lo stesso numero di trattini del bordo inferiore
		mov internW, CX
		mov AL,'-'
		repnz stosw
		;stampa angolo alto-dx
		mov AL,'\'
		stosw
		;salto alla riga successiva, partendo dall'angolo in alto-sx
		mov BX,rowPointer
		xor CH,CH
		mov CL,frameH
		dec CX
		dec CX
		mov DX,internW
		shl DX,1	;DX=distanza bordo sx-dx
		mov AL,'|'
		lblDraw:
			add BX,scrCols*2
			lea DI,[BX]
			stosw
			add DI,DX
			stosw
			dec CX
		ja lblDraw
		;disegno angolo basso-sx, riga inferiore e angolo basso-dx
		add BX,scrCols*2
		lea DI,[BX]
		mov AL,'\'
		stosw
		mov CX,internW
		mov AL,'-'
		repnz stosw
		mov AL,'/'
		stosw

		;pop CX
		jmp lblExitOk
		
		lblTooLarge LABEL near
		IFDEF VERBOSE
			push SI
			mov SI,offset msgTooLarge
			call DEBUG_P
			pop SI
		ENDIF
		mov AH, kErrLarge
		jmp lblExit
		lblTooLong LABEL near
		IFDEF VERBOSE
			push SI
			mov SI,offset msgTooLong
			call DEBUG_P
			pop SI
		ENDIF
		mov AH,kErrLong
		jmp lblExit

		lblExitOk:
		mov AH,kOk
		lblExit:
		IFDEF VERBOSE
			push SI
			push AX
			mov SI,offset msgFramepExit
			mov AL,AH
			call HEX2ASCII
			mov exitStatus,AX
			call DEBUG_P
			pop AX
			pop SI
		ENDIF
		ret
	FRAME_P endp

	;TEXT_P riempie un rettangolo con del testo
	;AX,DX come FRAME_P
	;DS:SI punta al testo (null terminated)
	;uso le stesse variabili di FRAME_P, TEXT_P non è mai chiamata da dentro
	;il corpo di FRAME_P
	TEXT_P proc near
		;INIZIALIZZO CALCOLANDO GLI INDIRIZZI DI INIZIO E FINE.

		;<<< copy/paste from frame_p >>>
		;Memorizzo le dimensioni del box
		mov word ptr frameW,AX

		;controllo se la dimensione rientra nello schermo
		mov BX,DX
		add BH,AH
		add BL,AL	;calcolo la posizione dell'ultimo punto
		dec BL		;decremento in quanto la dimensione è
		dec BH		;comprensiva dell'ultima riga/colonna

		cmp BH,scrRows-1 ;confronto con il bordo schermo
		ja toLongErrorTextP
		cmp BL,scrCols-1
		ja toLargeErrorTextP
		jmp toNormalPathTextP
		toLongErrorTextP:
			jmp lblTooLong
		toLargeErrorTextP:
			jmp lblTooLarge
		toNormalPathTextP:

		;Faccio puntare l'extra segment alla memoria video.
		mov BX,kSegVideo
		mov ES,BX
		
		;spostamento all'origine del box
		;evito la moltiplicazione per 80 facendo somme di shift
		xor BH,BH
		mov BL,DH	;numero di righe in BX
		mov CL,04h
		shl BX,CL	;righe*16 in BX
		mov CX,BX	
		shl CX,1	
		shl CX,1	;righe*64 in CX
		add BX,CX	;righe*80 in BX
		xor DH,DH
		mov DI,DX	;LEA vuole base registers. Uso SI per la colonna
		;lea DI,[DI][BX] ;in DI l'indirizzo di origine.
		add DI,BX
		shl DI,1	;DUE byte, uno per carattere, uno per attributi
		mov rowPointer,DI
		mov boxStart, DI
		;<<< end of copy/paste from FRAME_P >>>
		
		;calcolo l'indirizzo di memoria dell'ultimo punto
		mov frameH, AH	
		mov frameW, AL ;Salvo le dimensioni del box
		xor BH,BH	
		mov BL,AH
		dec BX		;righe numerate da 0. Un box con H=1 ha la riga di fine coincidente con l'inizio
		mov CL,04h
		shl BX,CL
		mov CX,BX
		shl CX,1
		shl CX,1
		add BX,CX   ;numero di righe del box * 80
		xor AH,AH
		dec AL	    ;un box composto da una sola colonna fa spostare l'indirizzo di 0 volte
		add BX,AX   ;BX=numero di caratteri che compongono il box
		shl BX,1    ;BX=numero di byte che compongono il box
		add DI,BX   ;DI=indirizzo di memoria dell'ultimo punto
		mov boxEnd, DI
		
		;Ciclo di riempimento del box
		;Controllo se sono in una posizione valida con il "cursore".
		;-Se no aggiusto la posizione
		;-Se si passo al punto successivo
		;Carico un carattere dalla stringa.
		;Se è stampabile lo stampo e avanzo
		;Se è un carattere di movimento (CR,LF,BS) muovo il cursore
		;Se è il terminatore esco
		;Se è un altro carattere lo ignoro.
				
		;frameW e frameH vengono ora decrementati di uno per gestire meglio gli spostamenti
		;e saranno espressi in BYTE.
		mov AH,frameH
		dec AH
		shl AH,1
		mov AL,frameW
		dec AL
		shl AL,1
		mov frameH,AH
		mov frameW,AL
		
		mov DI,boxStart	;spostamento all'inizio del box
		cld		;stringa per indirizzi crescenti

		mov CX,rowPointer
		add CL,frameW
		adc CH,0
		mov rowEnd,CX

		charLoop:
			;controllo posizione
			mov DX,boxEnd
			cmp DI,boxEnd ;abbiamo oltrepassato la fine del box?
			ja endPrint
			mov CX,rowEnd
			cmp DI,rowEnd ;se oltrepassiamo il bordo del box: CR+LF
			ja newRow
			
			lodsb	      ;carico un carattere della stringa
			cmp AL,00h    ;abbiamo raggiunto la fine della stringa?
			je  endPrint
			cmp AL,0Dh    ;Carriage return?
			je CRHandle
			cmp AL,0Ah    ;Line feed?
			je LFHandle
			
			mov AH,07h    ;attributo del carattere stampato
			stosw	      ;stampo il carattere

		jmp charLoop

		newRow:
			mov DI,rowPointer
			add DI,scrWidth ;CR+LF
			add rowPointer,scrWidth ;nuova riga
			add rowEnd,scrWidth     ;e nuovo fine riga
		jmp charLoop
		CRHandle:
			mov DI,rowPointer	;CR ritorna all'inizio della riga
		jmp charLoop

		LFHandle:
			add DI,scrWidth		;LF si sposta verticalmente di una riga
		jmp charLoop

		endPrint: 	;fine della stampa

		;<<< copy/pasted from FRAME_P >>>
		jmp lblExitOkTextP
		
		lblTooLargeTextP LABEL near
		IFDEF VERBOSE
			mov SI,offset msgTooLarge
			call DEBUG_P
		ENDIF
		mov AH, kErrLarge
		jmp lblExit
		lblTooLongTextP LABEL near
		IFDEF VERBOSE
			mov SI,offset msgTooLong
			call DEBUG_P
		ENDIF
		mov AH,kErrLong
		jmp lblExitTextP

		lblExitOkTextP:
		mov AH,kOk
		lblExitTextP:
		IFDEF VERBOSE
			push AX
			mov SI,offset msgFramepExit
			mov AL,AH
			call HEX2ASCII
			mov exitStatus,AX
			call DEBUG_P
			pop AX
		ENDIF
		ret
	TEXT_P endp

	;BOX_P checks for the carry flag. carry set=frame. carry clear=no frame.
	BOX_P proc near
		jc lblFrameful
		;frameless
		call TEXT_P
		ret
		lblFrameful:
		push AX
		push DX
		call FRAME_P
		pop DX
		pop AX
		inc DH
		inc DL
		dec AH
		dec AH
		dec AL
		dec AL
		call TEXT_P
		ret
	BOX_P endp

	IFDEF VERBOSE
	;in AL il byte da convertire, in AX i due ASCII corrispondenti
	HEX2ASCII proc near
		push BX
		push CX
		mov BL,AL
		mov CL,4
		shl BL,CL
		shr BL,CL ;azzerata il nibble più significativo
		add BL,'0'
		mov AH,BL ;in AH l'ASCII della cifra meno significativa.
		mov BL,AL
		shr BL,CL
		add BL,'0'
		mov AL,BL ;in AL l'ASCII della cifra più significativa
		;i numeri 0-9 a le lettere A-F non sono contigue in ASCII
		cmp AH,'9'
		ja nonNumeralAH
		checkNumeralAL:
		cmp AL,'9'
		ja nonNumeralAL
		jmp quitHex2Ascii
		nonNumeralAH:
			add AH,07h
			jmp checkNumeralAL
		nonNumeralAL:
			add AL,07h
		quitHex2Ascii:
		pop CX
		pop BX
		ret
	HEX2ASCII endp
	;stampa un messaggio di debug
	;mettere in SI l'offset del messaggio
	DEBUG_P proc near
		pusha ;mostrato come DB 60 dal debugger
		;"Vecchia" debug function che stampava il messaggio in basso
		;;dove era il cursore?
		;mov AH,03h	;cursor query
		;mov BH,kPage	;pagina di default
		;int 10h
		;push DX		;DX=posizione del cursore
		;;messaggio sull'ultima riga come un messaggio di stato
		;mov DH,scrRows-1
		;mov DL,0
		;mov AH,02h	;set cursor
		;int 10h
		;;pulisco la riga
		;mov CX,scrCols
		;;mov AH,0Ah ;mov AL,' '
		;mov AX,0A20h 	;stampa CX volte l'ASCII in AL
		;int 10h		;senza muovere il cursore

		;;stampa messaggio
		;mov DX,SI
		;mov AH,09h ;stampa messaggio DOS
		;int 21h
		;;attendo un tasto.
		;mov AH,00h	;key wait
		;int 16h		;BIOS keyboard services
		;;ritorno del cursore
		;pop DX
		;mov AH,02h
		;int 10h

		;"Nuova" debug function che stampa nel file di log
		mov DX,SI ;la funzione di scrittura su file vuole i dati in DS:DX
		mov DI,SI
		push DS
		pop ES
		mov CX,0FFFFh ;conteggio dei caratteri
		mov AL,'$'    ;cerco il terminatore
		cld
		repne scasb
		not CX
		dec CX ;togliamo il terminatore
		mov BX,logHandle
		mov AH,40h ;operazione di scrittura
		int 21h ;scriviamo il log
		;scriviamo un a capo
		mov CX,02h
		mov DX,offset newLine
		mov AH,40h
		int 21h
		popa
		ret
	DEBUG_P endp
	
	;DEBUG_INIT_P apre il file di log.
	DEBUG_INIT_P proc near
		pusha
		;3Ch non va bene per aprire file in scrittura su FAT 32
		;cambio con la funzione AX=6C00h
		;mov AH,3Ch ;crea file e lo apre in scrittura
		;mov DX,offset logFileName
		;mov CX,0	;nessun attributo speciale
		;int 21h	;apro il file
		mov AX,6C00h ;apri file "estesa"
		mov CX,00h   ;attributi creazione file
		;mov DH,00h   ;reserved. 
		;mov DL,11h   ;comportamento: 11=crea se non esiste, apri se esiste
		mov DX,0011h
		mov SI,offset logFileName
		;mov BL,01000001b ;sola scrittura, nessuna protezione, ereditato
		mov BL,41h
		mov BH,08h ;apertura "estesa" per FAT32
		int 21h
		jc @@	;check d'errore, label anonima
		mov logHandle,AX
		popa
		ret
		@@:
		mov AH,09h	;errore. stampo ed esco.
		mov DX,offset msgNoLog
		int 21h
		mov AX,4C00h
		int 21h
	DEBUG_INIT_P endp

	;DEBUG_END_P chiude il file di log
	DEBUG_END_P proc near
		pusha
		mov AH,3Eh
		mov BX,logHandle
		int 21
		popa
	DEBUG_END_P endp

	DEBUG_CUR_P proc near
		push AX
		mov SI, offset msgMoveCur
		mov AL,DH
		call HEX2ASCII
		mov curRow,AX
		mov AL,DL
		call HEX2ASCII
		mov curCol,AX
		call DEBUG_P
		pop AX
		ret
	DEBUG_CUR_P endp
	ENDIF	
CODE_S ends

end MAIN_P
