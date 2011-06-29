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
	
	; Dimensioni del box (inclusa cornice)
	frameW DB ?	; Larghezza
	frameH DB ?	; Altezza

	; Origine (offset da kSegVideo) del box
	boxMemOrig DW ?

	; Variabili per il disegno
	rowPointer DW ?	; rowPointer mantiene l'inizio della riga corrente
DATA_S ends

CODE_S segment public 'code'
	assume CS:CODE_S, DS:DATA_S, SS:STACK_S
; BOX_P disegna e riempie un rettangolo con del testo
; Parametri: 	AX dimensioni (AH righe, AL colonne)
;		DX origine (DH riga, DL colonna)
;		Direction flag: 1 frame, 0 no frame
;		DS:SI Stringa null-terminated testo del box
; Risultati: 	Carry bit settato su errore
; Registri sporcati: ES
BOX_P proc near
	; Memorizzo le dimensioni del box
	mov word ptr frameW,AX
	
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
	mov CL,04h
	shl BX,CL ; righe*16 in BX
	shl CX,1
	shl CX,1  ; righe*64 in CX
	add BX,CX ; righe*80 in BX
	shl BX,1  ; moltiplico per due: due byte per ogni carattere
	mov DI,BX ; imposto la destinazione per le funzioni di stringa
	xor DH,DH ; devo aggiungere il numero di colonne.
	add DI,DX ; DI=vera origine del box
	mov boxMemOrig,DI
	
	; Pulisco l'area di disegno
	pushf ;salvo i flags per mantenere il direction flag
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
		cmp BX,0
	ja lblClearBox
	
	popf

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
