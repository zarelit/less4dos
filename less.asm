; Implementazione di "less" per MS-DOS
; Autore: David Costa <david@zarel.net>
; Data di inizio: 17 Maggio 2011

; Definizione stack
STACK_S segment stack
STACK_S ends

; Definizione di variabili e costanti
DATA_S segment para 'data'
	;Segmento del Program Segment Prefix
	PSP DW ?
	BOXparams DB 'X='
	X DB ?
	  DB ' Y='
	Y DB ?
	  DB 0Dh,0Ah,'$'
	TestString 	DB 'Stringa di test. Contenuto del BOX',0Dh,0Ah
				DB 'Riga 2',0Dh,0Ah
				DB 'Riga 3',0Dh,0Ah
				DB 'Riga 4',0Dh,0Ah
				DB 'Riga 5',0Dh,0Ah
				DB 'Riga 6',0Dh,0Ah
				DB 'Riga 7',0Dh,0Ah
				DB 'Riga 8',0Dh,0Ah
				DB 'Riga 9',0Dh,0Ah
				DB 'Riga A',0Dh,0Ah
				DB 'Riga B',0Dh,0Ah,0
DATA_S ends

; Definizione del codice
CODE_S segment para 'code'
	;istruiamo l'assemblatore sul ruolo dei vari segmenti
	assume CS:CODE_S, DS:DATA_S, SS:STACK_S
	
	;procedura iniziale
	MAIN_P proc near
		;Carichiamo il registro DS con il nostro segmento dati
		mov AX, seg DATA_S
		mov DS, AX
		
		;Salviamo la locazione del PSP così da non richiederlo dopo
		mov PSP, ES
		
		;Cambiamo la modalità video
		; resetta il contenuto video
		;Testo 80x25 - 16 colori
		;Tabella modi: http://www.ctyme.com/intr/rb-0069.htm#Table10
		;mov AH,00h ; 00h = change video mode
		;mov AL,03h ; 03h = 80x25 16 colors
		mov AX, 0003h 
		int 10h
		
		; settiamo il cursore fullblock
		mov CX, 0007h 
		mov ah, 01h
		int 10h
		
		mov ah, 3
		mov al, 5
		;stampa myTestString
		push DS
		pop ES
		
		mov SI,offset TestString
		call BOX_P
		
		;Diciamo al dos di chiudere e liberare le risorse allocate
		; mov ah,4Ch - mov al,00h ;AL: codice ritorno
		mov AX, 4C00h
		int 21h
	MAIN_P endp

	;BOX_P riempie un rettangolo con del testo
	;riceve in ingresso un puntatore a una struttura così fatta:
	;ES:SI - Stringa ASCII null terminated.
	;AH,AL: X,Y
	;BH,BL: Width, Height
	BOX_P proc near
			
		; stampa gli argomenti con cui è stata chiamata la procedura
		;mov X,AH
		;mov Y,AL
		;add X,'0'
		;add Y,'0'
		;mov ah,09h
		;mov dx, offset boxparams
		;int 21h
		
		; Impostiamo l'origine del cursore - TODO: cambia coordinate
		mov dh, al ; Y
		mov dl, ah ; X
		mov bh, 0; pagina 0
		mov ah, 2; set cursor
		int 10h
		
		;mov ah, 0Ah ;stampa il carattere sul cursore e basta
		;mov bx, 0
		;mov cx, 3
		
		mov ah, 0Eh ;stampa teletype, avanza il cursore e scroll
					;ignora CX e BX - stampa sulla pagin corrente
		;mov al, 'A'
		cld ;clear directon, indirizzi aumentano
carica:
		lodsb ;moves [es:si] in AL		
		cmp al,0 ;confrontiamo col terminatore
		jz endString
		int 10h
		jmp carica
endstring:

		ret
	BOX_P endp
CODE_S ends

;Definizione entry point - termina l'assemblaggio
end MAIN_P
