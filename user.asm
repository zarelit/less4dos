; David Costa <david@zarel.net>
; Progetto per Calcolatori 2
; "less", un visualizzatore di file di testo

; Interazione con l'utente

%out Entering user.asm
DATA_S segment public 'data'
	; Messaggi di errore
	msgCode00 DB 'Programma eseguito senza errori','$'
	msgCode01 DB 'Richiesto disegno di un box troppo largo','$'
	msgcode02 DB 'Richiesto disegno di un box troppo lungo','$'
	msgCode03 DB 'Impossibile leggere il file dati','$'
	msgCode04 DB 'Nessun file fornito sulla riga di comando','$'
	msgCode05 DB 'Errore nella lettura del file dati','$'
	msgCode06 DB 'Errore lettura della posizione nel file dati','$'
	msgCodeUnknow DB 'Riscontrato un errore non specificato','$'

	; Menu
	msgMenu DB '(Q)uit        (F)ullscreen        (F1) Help',00h
	msgPosition DB '   %',00h
	msgHelp DB 0Dh,0Ah,' "Less" e'' un semplice visualizzatore di file '
		DB 'di testo ispirato dal piu'' noto programma per DOS "more".'
		DB 0Dh,0Ah,' Comandi disponibili:',0Dh,0Ah
		DB ' I tasti freccia su/giu scorrono riga per riga all''interno del file',0Dh,0Ah
		DB ' I tasti pagina su/pagina giu per lo scorrimento di pagina',0Dh,0Ah
		DB ' Il tasto "home" per ritornare all''inizio del file',0Dh,0Ah
		DB ' Il tasto "Q" o "ESC" per uscire dal programma.',0Dh,0Ah
		DB ' Il tasto "F1" per visualizzare nuovamente questa schermata.',0Dh,0Ah,0Dh,0Ah
		DB 0Dh,0Ah,'        =>Premi un tasto qualunque per tornare al testo<= ',00h

DATA_S ends

CODE_S segment public 'code'
	assume CS:CODE_S,DS:DATA_S,SS:STACK_S

; QUIT_P esce dal programma con il valore di ritorno in exitCode
QUIT_P proc near
	;Ripristino video mode originale - se è stato salvato
	;CMP mem, immediate può confrontare solo immediati fino a 127!!!
	;cmp dosVideoMode,0FFh
	;BUG del MASM o limite Intel? L'errore è una label che
	;si sposta tra le due passate
	mov BL,dosVideoMode
	cmp BL,0FFh
	je lblQuit
	mov AH,00h
	mov AL,dosVideoMode
	int 10h

	lblQuit:
	;Stampo una stringa che motiva l'uscita
	mov BL,exitCode
	cmp BL,00h
	;Salti relativi di 8 byte
	;2 jne + 3 mov + 2 jmp + 1 nop
	jne $+8
		mov DX,offset msgCode00
		jmp lblToDos
	cmp BL,01h
	jne $+8
		mov DX,offset msgCode01
		jmp lblToDos
	cmp BL,02h
	jne $+8
		mov DX,offset msgCode02
		jmp lblToDos
	cmp BL,03h
	jne $+8
		mov DX,offset msgCode03
		jmp lblToDos
	cmp BL,04h
	jne $+8
		mov DX,offset msgCode04
		jmp lblToDos
	cmp BL,05h
	jne $+8
		mov DX,offset msgCode05
		jmp lblToDos
	cmp BL,06h
	jne $+8
		mov DX,offset msgCode06
		jmp lblToDos
	lblUknknownError:
		mov DX,offset msgCodeUnknow
	
	;Esco dal programma
	lblToDos:
	mov AH,09h ;stampo l'errore
	int 21h
	mov AH,4Ch ;esco verso il DOS
	mov AL,exitCode
	int 21h
QUIT_P endp


; USER_P attende un input dall'utente e agisce di conseguenza.
USER_P proc near
	push AX
	mov AH,00h
	int 16h ; routine BIOS attendi tasto
	; AL=ASCII, AH=scancode
	
	;uscita dal programma (anche ESC)
	cmp AL,'q'
	je quitChoice
	cmp AL,'Q'
	je quitChoice
	cmp AH,01h
	je quitChoice
	;freccia giù, scroll down
	cmp AH,50h
	je scrDownChoice
	;freccia su, scroll up
	cmp AH,48h
	je scrUpChoice
	;pagina giù
	cmp AH,51h
	je pageDownChoice
	;pagina su
	cmp AH,49h
	je pageUpChoice
	;fullscreen
	cmp AL,'f'
	je fullScreenChoice
	cmp AL,'F'
	je fullScreenChoice
	; Ritorno all'inizio del file
	cmp AH,47h
	je homeChoice
	; Stampa help (Tasto F1)
	cmp AH,3Bh
	je helpChoice
	;nessuna scelta, esco senza azioni
	jmp quitUserP

	quitChoice:
		call QUIT_P
	scrDownChoice:
		call SCROLLDOWN_P
		jmp quitUserP
	scrUpChoice:
		call SCROLLUP_P
		jmp quitUserP
	pageDownChoice:
		call PAGEDOWN_P
		jmp quitUserP
	pageUpChoice:
		call PAGEUP_P
		jmp quitUserP
	fullScreenChoice:
		call FULLSCREEN_P
		jmp quitUserP
	homeChoice:
		call RESTART_P
		jmp quitUserP
	helpChoice:
		call HELP_P
		jmp quitUserP
	quitUserP:
	pop AX
	ret
USER_P endp

; Stampa un "help" come se fosse una barra di stato
PRINT_MENU_P proc near
	;ultima riga - senza frame
	mov AX,0150h
	mov DX,1800h
	mov SI,offset msgMenu
	mov CL,00h
	call BOX_P
	jc errMenu
	ret
	errMenu:
	call QUIT_P
PRINT_MENU_P endp

; FULLSCREEN_P commuta tra fullscreen e non
FULLSCREEN_P proc near
	mov BL,framePresence
	test BL,BL
	jz turnOffFS
	turnOnFS:
		;mov outerW,80
		mov outerH,25
		mov viewPortW,80
		mov viewPortH,25
		mov framePresence,00h
		ret
	turnOffFS:
		;mov outerW,80
		mov outerH,24
		mov viewPortW,78
		mov viewPortH,22
		mov framePresence,01h
		;ridisegno il menu scomparso prima
		call PRINT_MENU_P
		ret
FULLSCREEN_P endp

; Apre un riquadro con del testo informativo. Funzione dei tasti e autore.
HELP_P proc near
	mov AH,16
	mov AL,69
	mov CL,01h
	mov DL,5
	mov DH,3
	mov SI,offset msgHelp
	call BOX_P
	mov AH,00h
	int 16h ;aspetta un qualunque tasto per uscire
	ret
HELP_P endp

; POSITION_P disegna il box con la posizione che abbiamo raggiunto all'interno del file
POSITION_P proc near	
	mov AL,framePresence
	test AL,AL 
	jnz lblCalcPosition ;non disegno in FS
	ret
	lblCalcPosition: 
	; salvo i registri
	push SI
	push DI
	; leggiamo la posizione attuale (coincide sempre con la fine del buffer)
	mov AH,42h
	mov AL,01h
	mov CX,0000h
	mov DX,0000h
	mov BX,fileHandle
	int 21h
	jc positionPError
	; non tutto il buffer è stato disegnato
	mov BX,endOfBuffer
	sub BX,lastDrawn
	sub AX,BX
	sbb DX,0
	; per avere una percentuale devo moltiplicare l'offset per 100
	push DX
	mov BX,100
	mul BX
	;in DX:AX primo risultato intermedio
	mov SI,DX
	mov DI,AX
	pop AX
	mul BX
	;in DX:AX il secondo risultato intermedio
	xchg AX,DX
	mov AX,DI
	add DX,SI
	;in DX:AX offset * 100
	;in CX:BX il filesize
	mov CX,fileSizeHigh
	mov BX,fileSizeLow

	test CX,CX
	jnz keepCalcPos
	test BX,BX
	jnz keepCalcPos
	; Filesize=0, file is finished
	jmp lblCento

	keepCalcPos:
	call DIV32_P

	cmp AX,64h ;100
	je lblCento
	; in AX troviamo la percentuale
	mov BL,10
	div BL
	;in AL le decine, in AH le unità
	add AL,'0'
	add AH,'0'
	mov msgPosition[0],' '
	mov msgPosition[1],AL
	mov msgPosition[2],AH
	jmp lblDrawPos
	lblCento:
	mov msgPosition[0],'1'
	mov msgPosition[1],'0'
	mov msgPosition[2],'0'

	lblDrawPos:
	pop DI
	pop SI

	;disegno la percentuale
	mov DH,24
	mov DL,79-4
	mov AH,01
	mov AL,04
	mov CL,00
	mov SI,offset msgPosition
	call BOX_P

	ret
	
	positionPerror:
		pop DI
		pop SI
		mov exitCode,06h
		call QUIT_P 
POSITION_P endp

; GETFILESIZE_P richiede al DOS la dimensione del file aperto
GETFILESIZE_P proc near
	; Non esiste una funzione per avere la dimensione del file
	; Leggo la posizione corrente	
	mov AH,42h
	mov AL,01h ;dal cursore
	mov CX,0000h
	mov DX,0000h
	mov BX,fileHandle
	int 21h
	jc fileSizeErr
	push DX
	push AX
	; Quindi faccio uno spostamento di 0 bytes dalla fine del file
	; e leggo la posizione assoluta
	mov AH,42h
	mov AL,02h ;dalla fine del file
	mov CX,0000h
	mov DX,0000h
	mov BX,fileHandle
	int 21h
	jc fileSizeErr
	mov fileSizeHigh,DX
	mov fileSizeLow,AX
	; Ripristino lo stato precedente
	mov AH,42h
	mov AL,00h ; dall'origine
	pop DX
	pop CX
	mov BX,fileHandle
	int 21h
	jc fileSizeErr
	ret
	fileSizeErr:
		mov exitCode,06h
		call QUIT_P
GETFILESIZE_P endp

DIV32_P proc near
;------------------------------------------------------------------------------
;DIVIDE TWO 32-BIT NUMBERS BY EACH OTHER, USING ONLY 16-BIT OPERATIONS
;Inputs:  DX:AX = Dividend
;         CX:BX = Divisor
;Outputs: DX:AX = Quotient
;         CX:BX = Remainder
;Changes:
;NOTES: This is UNSIGNED division!
;       This is also a slow division process, but the code is small and
;         we only do it a few times in this program if we do it at all,
;         so there's no compelling need to optimize for speed.
;       This does not check for division by 0 (returns -1 instead of an error).
;       I find the code quite interesting, because it does not actually require
;         the CPU to do any divison at all -- only shifts, compares, and
;         subtracts.  The main reason it's so slow is that the loop must be
;         performed all 32 times -- there's no way to exit early.
;       This implementation came from The Art of Assembly Language by
;         Randall Hyde.  This is an ASM implementation of the following
;         pseudocode:
;
;       Quotient := Remainder;
;       Remainder := 0;
;       FOR I := 1 TO NumberOfBits DO
;         Remainder:Quotient := Remainder:Quotient SHL 1;
;         IF Remainder >= Divisor THEN
;           Remainder := Remainder - Divisor;
;           Quotient := Quotient + 1;
;          ENDIF
;        ENDFOR
;
;       During the entire routine:
;         DX:AX = Dividend
;         CX:BX = Divisor
;         SI:DI = Remainder
;------------------------------------------------------------------------------
  OR   CX,CX    ;Is the Divisor really 32 bits?
  JNZ  V20      ;If so, handle it
  CMP  DX,BX    ;Will we only need to do one division?
  JB   V10      ;If so, jump to handle it
  MOV  CX,AX    ;CX = Dividend-Low
  MOV  AX,DX    ;DX:AX =
  XOR  DX,DX    ;  Dividend
  DIV  BX       ;Do the Division (AX = Quotient)
  XCHG AX,CX    ;CX = Quotient-High, AX = Dividend-Low
V10:            ;First division handled, if appropriate
  DIV  BX       ;AX = Quotient-Low
  MOV  BX,DX    ;BX = Remainder-Low
  MOV  DX,CX    ;DX = Quotient-High
  XOR  CX,CX    ;CX = Remainder-High
  JMP  V90      ;Done

V20:            ;Divisor really is 32 bits
  PUSH DI
  push SI
  push BP ;Save used registers
  MOV  BP,32    ;Do 32 bits
  XOR  SI,SI    ;Remainder :=
  XOR  DI,DI    ;  0
V30:            ;Loop to here for each bit
  SHL  AX,1     ;Remainder:Quotient :=
  RCL  DX,1     ;  Remainder:Quotient
  RCL  DI,1     ;  SHL
  RCL  SI,1     ;  1
  CMP  SI,CX    ;Remainder HO word more than Divisor HO word?
  JA   V40      ;If so, handle it
  JB   V50      ;If not, we're done with this bit
V35:            ;Remainder HO word = Divisor HO word
  CMP  DI,BX    ;Remainder LO word more than Divisor LO word?
  JB   V50      ;If not, we're done with this bit
V40:
  SUB  DI,BX    ;Remainder :=
  SBB  SI,CX    ;  Remainder - Divisor
  INC  AX       ;Increment Quotient
V50:            ;Go to the next bit
  DEC  BP       ;Decrement Loop Counter
  JNZ  V30      ;If not 0 yet, keep looking
  MOV  CX,SI    ;Put Remainder
  MOV  BX,DI    ;  in CX:BX for the return
  POP  BP
  pop  SI
  pop  DI ;Restore used registers
V90:            ;Done
  RET
DIV32_P endp

CODE_S ends
