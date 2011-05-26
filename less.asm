; Implementazione di "less" per MS-DOS
; Autore: David Costa <david@zarel.net>
; Data di inizio: 17 Maggio 2011

; Definizione stack
STACK_S segment stack
STACK_S ends

; Definizione di variabili e costanti
DATA_S segment para 'data'

	;The test string
IFDEF longtest
	theTestString DB 'A very long text string that exceeds the width'
				  DB ' of the screen with its useless content',0,'$'
ELSE
IFDEF loremtest
	theTestString DB 'Lorem ipsum dolor sit amet, consectetur '
				  DB 'adipiscing elit. Donec a diam lectus. Sed sit '
				  DB 'amet ipsum mauris. Maecenas congue ligula ac '
				  DB 'quam viverra nec consectetur ante hendrerit. '
				  DB 'Donec et mollis dolor. Praesent et diam eget '
				  DB 'libero egestas mattis sit amet vitae augue. '
				  DB 'Nam tincidunt congue enim, ut porta lorem lacinia'
				  DB ' consectetur. Donec ut libero sed arcu vehicula '
				  DB 'ultricies a non tortor. Lorem ipsum dolor sit '
				  DB 'amet, consectetur adipiscing elit. Aenean ut '
				  DB 'gravida lorem.',0
ELSE
	theTestString DB 'The test string.',0,'$'
ENDIF
	defaultPage	DB ?
	;origine del box - bordo sx e alto
	origCol DB ?
	origRow DB ?
	;bordo del box - dx e basso
	lastCol DB ?
	lastRow DB ?
	;dimensione del box
	sizeW	DB ?
	sizeH	DB ?
	
DATA_S ends

; Definizione del codice
CODE_S segment para 'code'
	;istruiamo l'assemblatore sul ruolo dei vari segmenti
	assume CS:CODE_S, DS:DATA_S, SS:STACK_S
	
	;procedura iniziale
	MAIN_P proc near
		;impostiamo DS
		mov AX,seg DATA_S
		mov DS,AX

		;main di test per la procedura BOX_P
		mov ES,AX ;facciam puntare ES come DS
		mov SI,offset theTestString
		mov DX, 0205h ;testo a partire da riga 3 col 6
		mov CX, 0303h ;testo in un box 3x3
		call BOX_P
		
		;tentativo
		mov fs,ax
		
		;uscita dal programma
		;mov AH,4Ch; mov AL,00h;
		mov AX, 4C00h
		int 21h
		
	MAIN_P endp
	
	;;		BOX_P
	;	riempie un rettangolo con del testo
	;ES:SI - puntatore alla stringa contenuto (null terminated)
	;DH=row, DL=column - Coordinate partenza - DX=(y,x)
	;CH=height, CL=width - Dimensioni box
	;
	BOX_P proc near

		;NOTA: 	i caratteri non stampabili rendono difficile la gestione
		;		del cursore in quanto rendono difficilmente prevedibile
		;		(a meno di non controllare tutte le casistiche) la nuova
		;		posizione del cursore.
		;		La filosofia che si segue ora è lasciar fare al bios
		;		l'avanzamento del cursore e aggiustare poi il cursore
		; 		per farlo rientrare nel box
		
		;NOTA2: Questa funzione permette di disegnare box con cornici.
		;		Al fine di velocizzare le operazioni di disegno in caso
		;		di box senza testo (a volte utili) il disegno della
		;		cornice e del testo sono separate e disegnare un box
		;		con testo e cornice equivale a disegnare la cornice
		;		e poi il testo in un box un po' più piccolo e frameless
		
		;===> NEW mode
		;usa la teletype print e poi controlla dove si trova il cursore
		cld				;DF=0, gli indirizzi sono crescenti
		
		;I registri general purpose non ci bastano perchè le chiamate
		;al BIOS ne vogliono parecchi settati e quindi non possiamo
		;contenere i valori che ci servono durante tutta la stampa
		
		;salviamo i parametri con cui siamo stati chiamati
		;mov origCol, DL; mov origRow, DH
		mov word PTR origCol, DX
		;mov width, CL; mov height, CH
		mov word PTR sizeW, CX
		;calcoliamo il bordo della finestra
		mov word PTR lastCol, DX
		add lastCol,CL
		add lastRow,CH
		
		
		;get video mode - AH=0Fh
		;ritorna: AH=#cols, AL=disp mode, BH=#active page
		mov AH,0Fh
		int 10h
		mov defaultPage,BH ;salviamo la pagina di default
		
		;Impostiamo l'origine del cursore
		;AH=02H, BH=#page, DH=row, DL=column
		mov AH, 02h
		int 10h
		
	newmode:
		mov AH, 0Eh		;stampa teletype del bios
		lodsb			;carichiamo un byte dalla stringa
		cmp AL, 00h		;se è il terminatore si esce
		je endnewmode
		int 10h			;se non è il terminatore si stampa
		
		;stato cursore
		;params: AH=03h, BH=#pagina 
		;ritorna AX=0,CH=#scanline start, CL=#scanline end,
		;		 DH=Row, DL=Column
		mov AH, 03h
		int 10h
		
		
		
		jmp	newmode		;e si passa alla lettera successiva
	endnewmode:
		
IFDEF tty ;TTY mode - solo per test
		;stampa la stringa usando la funzione BIOS
		;"teletype print" che avanza il cursore da sola
		;AH=0Eh, AL=char, BH=#page, BL=colore(in grafica)
		cld ;DF=0, gli indirizzi aumentano
		mov AH, 0Eh
	printtty:
		lodsb			;in AL il carattere della stringa
		cmp AL, 00h 	;se il carattere è NUL usciamo
		je endprinttty	;altrimenti lo stampiamo
		int 10h			;chiamata al BIOS
		jmp printtty
	endprinttty:		;Fine ciclo stampa
ENDIF ;end TTY mode

IFDEF dumb
		;Cursore autogestito
		;inizialmente il cursore si trova all'angolo alto/destra del box
		;stampa BIOS del carattere
		;AH=0Ah, AL=char, BH=#page, CX=#repeat char
		mov CX, 01h
	print:
		mov AH, 0Ah
		lodsb			;in AL il carattere della stringa
		cmp AL, 00h		;se il carattere è NUL usciamo
		je endprint
		int 10h			;altrimenti lo stampiamo
		
		;calcolo del punto successivo
		inc DL	;per il momento è sulla colonna successiva
		mov ah, 02h ;spostiamo il cursore
		int 10h
		
		jmp print
	endprint:
ENDIF ;end DUMB print

		ret
	BOX_P endp
	
CODE_S ends

;Definizione entry point - termina l'assemblaggio
end MAIN_P
