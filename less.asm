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
	kPage	EQU 00h		;pagina di testo di default
	kSegVideo EQU 0B800h	;segmento video. Lo 0 davanti al numero è necessario a MASM
	;Valori di uscita da FRAME_P 
	kOk	  EQU 00h	;box disegnato
	kErrLarge EQU 01h	;box troppo largo
	kErrLong  EQU 02h	;box troppo lungo

	;variabili globali e di MAIN_P
	oldMode	DB ?	;Modo video prima dell'ingresso nel programma
	testText DB 'Una interessante stringa che non va a capo',0h

	;variabili usate da FRAME_P
	frameW DB ?	;Larghezza
	frameH DB ?	;Altezza
	internW DW ?	;numero trattini orizzontali
	internH DW ?	;numero trattini verticali
	rowPointer DW ?	;indirizzo inizio riga corrente
	
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

		;Chiamata di test a FRAME_P
		;Fullscreen
		mov AX,1950h
		mov DX,0000h
		;Esempio
		;mov DX,0305h
		;mov AX,0506h
		;Esempio sul bloc notes
		;mov AX,0406h
		;mov DX,0201h
		IFDEF VERBOSE
			push AX
			push DX
			call HEX2ASCII ;converto AL
			mov callAL,AX
			mov AL,AH
			call HEX2ASCII
			mov callAH,AX
			mov AL,DH
			call HEX2ASCII
			mov callDH,AX
			mov AL,DL
			call HEX2ASCII
			mov callDL,AX
			mov SI, offset msgCallFrameP
			call DEBUG_P
			pop DX
			pop AX
		ENDIF
		call FRAME_P

		;Ripristino il modo video precedente
;		mov AH,00h	;Video-mode set
;		mov AL,oldMode
;		int 10h

		;Esco correttamente al dos
		IFDEF VERBOSE
			call DEBUG_END_P
		ENDIF
		;AH=4C, AL=valore ritorno
		mov AX, 4C00h
		int 21h
	MAIN_P endp
	
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
		mov SI,DX	;LEA vuole base registers. Uso SI per la colonna
		lea DI,[SI][BX] ;in DI l'indirizzo di origine.
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
			mov SI,offset msgTooLarge
			call DEBUG_P
		ENDIF
		mov AH, kErrLarge
		jmp lblExit
		lblTooLong LABEL near
		IFDEF VERBOSE
			mov SI,offset msgTooLong
			call DEBUG_P
		ENDIF
		mov AH,kErrLong
		jmp lblExit

		lblExitOk:
		mov AH,kOk
		lblExit:
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
	FRAME_P endp

	;TEXT_P riempie un rettangolo con del testo
	;AX,DX come FRAME_P
	;DS:SI punta al testo (null terminated)
	;uso le stesse variabili di FRAME_P, TEXT_P non è mai chiamata da dentro
	;il corpo di FRAME_P
	TEXT_P proc near
		mov word ptr frameW,AX
		
	TEXT_P endp

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
