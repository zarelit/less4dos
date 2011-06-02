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
	;stringhe e variabili di debug.
	IFDEF VERBOSE
		msgTooLarge DB 'Box richiesto troppo largo.$'
		msgTooLong DB 'Box richiesto troppo lungo.$'
		msgChgMode DB 'Modo video cambiato in ',videoMode+'0','h.$'
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
		xor AX,AX
		xor DX,DX
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
		
		;controllo se la dimensione rientra nello schermo
		mov BX,DX
		add BH,AH
		add BL,AL
		
		cmp BH,scrRows
		jb lblTooLong
		cmp BL,scrCols
		jb lblTooLarge

		;salvo la posizione dei bordi
		mov lastRow,BH	;ultima riga
		mov lastCol,BL	;ultima colonna
		
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
		pusha
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
	ENDIF	
CODE_S ends

;fine assemblaggio, dichiaro l'entry point
end MAIN_P
