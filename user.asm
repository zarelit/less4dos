; Interazione con l'utente

CODE_S segment public 'code'
	assume CS:CODE_S,DS:DATA_S,SS:STACK_S

; QUIT_P esce dal programma con il valore di ritorno in exitCode
QUIT_P proc near
	;Ripristino video mode originale - se è stato salvato
	;CMP mem, immediate può confrontare solo immediati fino a 127!!!
	;cmp dosVideoMode,0Fh
	;BUG del MASM o limite Intel? L'errore è una label che
	;si sposta tra le due passate
	mov BL,dosVideoMode
	cmp BL,0FFh
	je lblQuit
	mov AH,00h
	mov AL,dosVideoMode
	int 10h

	;Esco dal programma
	lblQuit:
	mov AH,4Ch
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
	;nessuna scelta, esco senza azioni
	jmp quitUserP

	quitChoice:
		call QUIT_P
	
	jmp quitUserP

	quitUserP:
	pop AX
	ret
USER_P endp

CODE_S ends
