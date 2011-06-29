; Codice per disegnare box e riempirli con testo

; Variabili delle funzioni contenute in questo file
; Le variabili locali non sono sullo stack in quanto
; non si necessita rientranza
DATA_S segment public 'data'
	; Costanti
	kScrRows EQU 25 ; 19h
	kScrCols EQU 80 ; 50h
	kRowBytes EQU kScrCols*2
	kSegVideo EQU 0B800h ; Inizio della memoria video
	kDefAttr EQU 07h ; Attributo testo bianco su sfondo nero
	
	; Dimensioni del box
	frameW DB ?	; Larghezza (inclusa la cornice)
	frameH DB ?	; Altezza (cornice inclusa)
	innerW DW ?	; Larghezza (cornice esclusa)
	innerH DW ?	; Altezza (cornice esclusa)

	; Opzioni di disegno
	boxOpts DB ?	; Opzioni

	; Origine (offset da kSegVideo) del box
	boxMemOrig DW ?
	; Fine del box
	boxMemEnd DW ?

	; Variabili per il disegno
	rowPointer DW ?	; rowPointer mantiene l'inizio della riga corrente
	rowEnd	DW ? ;rowEnd mantiene la fine della riga corrente
DATA_S ends

CODE_S segment public 'code'
	assume CS:CODE_S, DS:DATA_S, SS:STACK_S
; BOX_P disegna e riempie un rettangolo con del testo
; Parametri: 	AX dimensioni (AH righe, AL colonne)
;		DX origine (DH riga, DL colonna)
;		CX: opzioni (bit 0:frame)
;		DS:SI Stringa null-terminated testo del box
; Risultati: 	Carry bit settato su errore
; Registri sporcati: ES
BOX_P proc near
	; Memorizzo le dimensioni del box e le opzioni
	mov word ptr frameW,AX
	mov boxOpts,CL	
	; Check dimensioni
	mov BX,DX
	add BH,AH
	add BL,AL
	dec BL
	dec BH	; BX=coordinate dell'ultimo punto

	cmp BH,kScrRows-1 ;Non abbastanza righe sullo schermo
	ja toLongError
	cmp BL,kScrCols-1  ;Non abbastanza colonne sullo schermo
	ja toLargeError
	jmp toNormalPath
	
	toLongError:
		jmp lblTooLong
	toLargeError:
		jmp lblTooLarge
	toNormalPath:
	
	; Faccio puntare l'extra segment alla memoria video
	mov BX,kSegVideo
	mov ES,BX

	; Calcolo l'origine del box
	; Usando le funzioni di stringa il nostro "cursore" è DI
	; Origine=(riga*kScrCols+colonna)*2
	; Lavoriamo sempre con 80 colonne: somme di shift per moltipl. per 80
	xor BH,BH
	mov BL,DH ; BL=riga dell'origine
	mov CX,0004h
	shl BX,CL ; righe*16 in BX
	mov CX,BX
	shl CX,1
	shl CX,1  ; righe*64 in CX
	add BX,CX ; righe*80 in BX
	mov DI,BX ; imposto la destinazione per le funzioni di stringa
	xor DH,DH ; devo aggiungere il numero di colonne.
	add DI,DX ; DI=vera origine del box
	shl DI,1
	mov boxMemOrig,DI
	
	; Pulisco l'area di disegno
	cld  
	mov rowPointer,DI
	mov AL,' '
	mov AH,kDefAttr ;scriviamo blank chars
	mov BL,frameH ;in BX l'altezza del box
	xor BH,BH
	lblClearBox:
		xor CH,CH
		mov CL,frameW ;in CX la larghezza del box
		repnz stosw
		add rowPointer,kRowBytes
		mov DI,rowPointer ; spostamento alla riga successiva
		dec BX
	ja lblClearBox
	
	; Disegno del frame (se richiesto)
	mov CL,boxOpts
	test CL,01h ;test per il bit "frame enabled"
	jz drawNoFrame ;se il frame non è richiesto salta al testo
	
	; resetto le coordinate dalla pulizia del box
	mov DI,boxMemOrig
	mov rowPointer,DI

	; angolo up-L
	mov AL,'/'
	mov AH,kDefAttr
	stosw
	; riga TOP
	xor CH,CH
	mov CL,frameW
	dec CX
	dec CX
	mov innerW,CX ; salvo la larghezza "interna" del box
	mov AL,'-' ; attributo invariato
	repnz stosw
	; angolo UP-R
	mov AL,'\'
	stosw
	; righe verticali L e R
	; uso CX per contare il numero di righe "interne"
	xor CH,CH
	mov CL,frameH
	dec CX
	dec CX
	mov DX,innerW
	shl DX,1 ; DX: distanza in bytes tra i due bordi verticali
	mov AL,'|'
	mov BX, boxMemOrig ;BX è il puntatore alla riga
	mov DI,BX
	lblVerts:
		add BX,kRowBytes
		mov DI,BX ;spostamento alla riga successiva
		stosw ;cambia DI, non BX!
		add DI,DX ;spostamento a destra
		stosw
		dec CX
	ja lblVerts
	; angolo DOWN-L
	add BX,kRowBytes
	mov DI,BX
	mov AL,'\'
	stosw
	; riga BOTTOM
	mov CX,innerW
	mov AL,'-'
	repnz stosw
	; angolo DOWN-R
	mov AL,'/'
	stosw
	; FINE disegno cornice

	; Prima di riempire con il testo, "ridimensioniamo" il box
	; L'origine si sposta di una riga e una colonna
	add boxMemOrig,kRowBytes+2
	; Verranno utilizzate le dimensioni interne. Non è stata ancora calcolata l'altezza interna
	mov AL,frameH
	dec AL
	dec AL
	xor AH,AH
	mov innerH,AX
	jmp drawText

	; senza frame le dimensioni interne sono uguali alle esterne
	drawNoFrame:
	mov BL,frameH
	mov AL,frameW
	xor BH,BH
	xor AH,AH
	mov innerH,BX
	mov innerW,AX

	; disegno del testo
	drawText:
	; calcolo l'ultimo indirizzo di memoria del box
	dec BX ;un box con monoriga ha la fine e l'inizio sulla stessa riga!
	mov CL,04h
	shl BX,CL
	mov CX,BX
	shl CX,1
	shl CX,1
	add BX,CX ;(righe del box-1)*80
	;xor AH,AH (già fatto prima)
	dec AL
	add BX,AX ; aggiungo il numero di colonne
	shl BX,1 ;BX= numero di bytes che compongono il box
	mov AX,boxMemOrig
	add AX,BX
	mov boxMemEnd,AX

	; calcolo l'indirizzo di fine della riga corrente
	mov CX,innerW
	shl CX,1
	add CX,boxMemOrig
	mov rowEnd,CX

	; Posizionamento all'inizio dell'area utile
	mov DI,boxMemOrig
	mov rowPointer,DI

	; ciclo di riempimento effettivo
	mov DX,boxMemEnd
	mov CX,rowEnd
	mov AH,kDefAttr
	charLoop:
		; controllo di posizione
		cmp DI,DX ;abbiamo oltrepassato il fine box?
		ja endPrint
		cmp DI,CX ;abbiamo oltrepassato il bordo destro?
		ja newRow

		;siamo in una posizione valida
		lodsb
		cmp AL,00h ;raggiunto il fine stringa?
		je endPrint
		cmp AL,0Dh ; Carriage return?
		je CRHandle
		cmp AL,0Ah ; Line feed?
		je LFHandle

		stosw ;stampa carattere
	jmp charLoop

	; Gestione casi speciali
	newRow:
		mov DI,rowPointer
		add DI,kRowBytes ;CR+LF
		mov rowPointer,DI
		;add rowEnd,kRowBytes
		;si usa CX nel ciclo
		add CX,kRowBytes ;sposto il fine riga... di una riga
	jmp charLoop

	CRHandle:
		mov DI,rowPointer ;CR sposta a inizio riga
	jmp charLoop

	LFHandle:
		add DI,kRowBytes ;LF sposta verticalmente di una riga
	jmp charLoop

	endPrint: ;fine della stampa

	; Corretta uscita dalla procedura
	clc ;clear carry - tutto ok
	ret

	; Gestione degli errori incontrati durante il disegno
	lblTooLarge:
	lblTooLong:
		stc ;set carry - errore
	ret
BOX_P endp
CODE_S ends
