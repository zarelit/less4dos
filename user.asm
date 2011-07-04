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
	msgMenu DB '(Q)uit        (F)ullscreen',00h

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
	
	;uscita dal programma
	cmp AL,'q'
	je quitChoice
	cmp AL,'Q'
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

CODE_S ends
