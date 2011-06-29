; Main file

; Inclusione delle varie parti del codice
include box.asm

; Global stack
STACK_S segment stack
	DB 256 dup('STACK:-)')
STACK_S ends

; Global data
DATA_S segment public 'data'
	exitCode DB 0	;vedi Codici di uscita
	stupidGarbage DB 'SlLvmf842]JX w^-_T/*7]"a+DM^&o-mb+x2WBpY','$'
DATA_S ends

; Main program
CODE_S segment public 'code'
	assume CS:CODE_S, DS:DATA_S, SS:STACK_S

MAIN_P proc near
	; load DS with the right value
	mov AX,seg DATA_S
	mov DS,AX

	; stupid test: fill the screen with garbage
	mov CX,49
	garbageFill:
	mov AH,09h
	mov DX,offset stupidGarbage
	int 21h
	dec CX
	cmp CX,0
	ja garbageFill
	;proviamo a cancellare un po' di box
	mov AH,03
	mov AL,04
	mov DX,0101h
	call BOX_P
	
	;Uscita al DOS
	mov AH,4Ch
	mov AL,exitCode
	int 21h
MAIN_P endp

CODE_S ends

; Entry point
end MAIN_P

; Codici di uscita
; 0 - Nessun errore riscontrato
