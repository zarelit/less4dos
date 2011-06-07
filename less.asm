; Progetto per l'esame di Calcolatori 2
; David Costa

STACK_S segment stack
	DB 256 dup('STACK+-~') ;Ogni ripetizione occupa 8 byte (4 word)
STACK_S ends

DATA_S segment 'data'
	;Opzioni
	videoMode EQU 03h	;modo video 80x25
	scrCols	EQU 80		;|coerente con videoMode
	scrRows EQU 25		;|coerente con videoMode
	kPage	EQU 00h		;pagina di testo di default
	;Valori di uscita da FRAME_P 
	kOk	  EQU 00h	;box disegnato
	kErrLarge EQU 01h	;box troppo largo
	kErrLong  EQU 02h	;box troppo lungo

	;variabili globali e di MAIN_P
	oldMode	DB ?	;Modo video prima dell'ingresso nel programma

	;variabili usate da FRAME_P
	lastCol	DB ?	;X+Width
	lastRow	DB ?	;Y+Height
	startCol DB ?	;X
	startRow DB ?	;Y
	;stringhe e variabili di debug.
	IFDEF VERBOSE
		msgTooLarge DB 'Box richiesto troppo largo.$'
		msgTooLong DB 'Box richiesto troppo lungo.$'
		msgChgMode DB 'Modo video cambiato in ',videoMode+'0','h.$'
		msgMoveCur DB 'Muovo il cursore in (riga, colonna) ('
		curRow	DB ?,','
		curCol  DB ?,')$'
		msgFramepExit DB 'Esco da FRAME_P. con stato '
		exitStatus    DB ? , '$'
	ENDIF
DATA_S ends

;Direttiva sul processore. La CPU di default (8086) non implementa
;alcune istruzioni tra cui PUSHA e POPA
.186

CODE_S segment para 'code'
	;Controllo dei segmenti
	assume CS:CODE_S, DS:DATA_S, SS:STACK_S
	
	;Punto d'ingresso.
	MAIN_P proc near
		;Imposto il DS, ora contiene l'indirizzo del PSP
		mov AX, seg DATA_S
		mov DS, AX

		;Salvo il modo video corrente
		mov AH,0Fh	;Video-mode query
		int 10h		;il video mode in AL
		mov oldMode,AL
		
		;Imposto l'80x25
		;TODO: modo 02h e 03h cosa cambia in VGA?
		mov AX,0003h
		int 10h
		IFDEF VERBOSE
			;stampo conferma cambio modo
			mov SI,offset msgChgMode
			call DEBUG_P
		ENDIF		

		;Chiamata di test a FRAME_P
		mov AX,0406h
		mov DX,0201h
		call FRAME_P

		;Ripristino il modo video precedente
;		mov AH,00h	;Video-mode set
;		mov AL,oldMode
;		int 10h

		;Esco correttamente dal dos
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

		;Memorizzo l'origine del box
		mov word ptr startCol,DX

		;controllo se la dimensione rientra nello schermo
		mov BX,DX
		add BH,AH
		add BL,AL	;calcolo la posizione dell'ultimo punto
		dec BL		;decremento in quanto la dimensione è
		dec BH		;comprensiva dell'ultima riga/colonna

		cmp BH,scrRows-1 ;confronto con il bordo schermo
		ja lblTooLong
		cmp BL,scrCols-1
		ja lblTooLarge

		;salvo la posizione dell'ultimo punto
		;mov lastRow,BH	;ultima riga ;mov lastCol,BL	;ultima colonna
		mov word ptr lastCol,BX ;punto basso-dx

		;salvo la posizione attuale del cursore
		mov AH, 03h
		mov BH, kPage
		int 10h
		push DX

		;disegno della cornice
		; "/" o "\" per gli angoli, "|" o "-" per le linee
		mov AH,02h
		mov DX,word ptr startCol
		int 10h		;cursore alto-sx
		IFDEF VERBOSE
			call DEBUG_CUR_P
		ENDIF

		;stampa teletype per la riga in alto
		;mov AH,0Eh ;mov AL,'/'
		mov AX,0E2Fh
		int 10h		;stampa angolo alto-sx
		xor CH,CH	;stampa bordo alto, no angolo alto-dx
		mov CL,lastCol
		sub CL,startCol
		dec CL
		push CX		;lo stesso # di trattini ci serve per il bordo basso
		mov AL,'-'
		;non posso usare REP con INT, non funziona.
		;repnz int 10h
		;TODO: verifica quando il conteggio è già zero!
		upper:
			int 10h	
			dec CX
		jnz upper
		mov AL,'\'	;stampa angolo alto-dx
		int 10h
		;stampa teletype per la riga in basso, prima muovo il cursore
		mov AX,02h
		mov DH,lastRow
		mov DL,startCol
		int 10h		;cursore basso-sx
		IFDEF VERBOSE
			call DEBUG_CUR_P
		ENDIF
		mov AX,0E5Ch	;stampa angolo basso-sx
		int 10h
		pop CX		;carico il numero di trattini calcolato prima
		mov AL,'-'
		lower:
			int 10h
			dec CX
		jnz lower
		mov AL,'/'	;stampa angolo basso-dx
		int 10h


		;disegno completato, da qui in poi codici di uscita
		;ripristino la posizione precedente del cursore
		mov AH,02h
		mov BH,kPage
		pop DX
		int 10h
		IFDEF VERBOSE
			call DEBUG_CUR_P
		ENDIF
		jmp lblExitOk
		
		lblTooLarge:
		IFDEF VERBOSE
			mov SI,offset msgTooLarge
			call DEBUG_P
		ENDIF
		mov AH, kErrLarge
		jmp lblExit
		lblTooLong:
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
			mov SI,offset msgFramepExit
			mov exitStatus,AH
			add exitStatus,'0'
			call DEBUG_P
		ENDIF
		ret
	FRAME_P endp

	IFDEF VERBOSE
	;stampa un messaggio di debug
	;mettere in SI l'offset del messaggio
	DEBUG_P proc near
		pusha ;mostrato come DB 60 dal debugger
		;dove era il cursore?
		mov AH,03h	;cursor query
		mov BH,kPage	;pagina di default
		int 10h
		push DX		;DX=posizione del cursore
		;messaggio sull'ultima riga come un messaggio di stato
		mov DH,scrRows-1
		mov DL,0
		mov AH,02h	;set cursor
		int 10h
		;stampa messaggio
		mov DX,SI
		mov AH,09h ;stampa messaggio DOS
		int 21h
		;attendo un tasto.
		mov AH,00h	;key wait
		int 16h		;BIOS keyboard services
		;ritorno del cursore
		pop DX
		mov AH,02h
		int 10h
		popa
		ret
	DEBUG_P endp

	DEBUG_CUR_P proc near
		mov SI, offset msgMoveCur
		mov curRow,DH
		mov curCol,DL
		add curCol,'0'
		add curRow,'0'
		call DEBUG_P
	DEBUG_CUR_P endp
	ENDIF	
CODE_S ends

;fine assemblaggio, dichiaro l'entry point
end MAIN_P
