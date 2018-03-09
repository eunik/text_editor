model tiny
.386
.data
	filename	db 8 dup(?)			;name of file to open
	handle		dw 0
	in_buffer	db 255				;file data buffer
	out_buffer	db 2000 dup(' ')	;out buffer data
	empty		db 2000 dup(' ')
	emsg		db 'Cannot open file.$'
	smsg		db 'File is too big.$'
	rmsg		db 'Cannot read file.$'
	wmsg		db 'Cannot write file.$'
	cmsg		db 'Cannot close file.$'
.code
org 100h
;-----------------------------------PROCS-----------------------------------
start:
	call CONSOLE		; read psp
	call OPENFILE
	jc   EXIT     		; jump if error
	call READFILE
	jc   EXIT     		; jump if error
	call WRITEFILE
	jc   EXIT     		; jump if error
	call CLOSEFILE
EXIT:  .EXIT
;DOS exit
	; mov     ah,4Ch
	; int     21h
;--------------------------------READING PSP---------------------------
CONSOLE PROC NEAR
	mov		bx, offset 082h			; get the text from psp
	mov		si, offset filename		; index for file name
	mov		dl, [bx]				; inputs the next character
	cmp		dl, 0 					; check if user did not type anything
	je		proceed
read_psp:
	mov		byte ptr[si], dl		; store from psp
	inc		bx
	inc		si
	mov		dl, [bx]				; inputs the next character
	cmp		dl, 0Dh 				; check for CR
	je		proceed					; jumps to end of file
	jmp		read_psp
proceed:
	ret
CONSOLE	ENDP

;-------------------------------------------OPEN FILE--------------------
OPENFILE PROC NEAR
	mov 	ax, 3D02h				;open file with handle function
	mov		dx, offset filename		;set up pointer to ASCIIZ string
	int		21h						;DOS call
	jc		filerror				;jump if error
	mov		handle, ax				;save file handle
	mov		si, 1					;for checking file line size
	mov		di, 0					;for index of new in_buffer
	;set video mode and clear screen
	mov     ah,0       				;set mode function
	mov     al,3       				;80x25 color text
	int     10h        				;set mode
	ret	
filerror:
	lea		dx, emsg				;set up pointer to error message
	mov  	ah, 9					;display string function
	int		21h						;DOS call
	stc								;set error flag
	ret
OPENFILE ENDP

;------------------------------------------READ FILE--------------------
READFILE PROC NEAR
	mov		ah, 3Fh   			;read from file function
	mov		bx, handle			;load file handle
	lea		dx, in_buffer		;set up pointer to data in_buffer
	mov		cx, 1     			;read one byte
	int		21h      			;DOS call
	jc 		readerror  			;jump if error
	cmp		ax, 0     			;were 0 bytes read?
	jz 		eof     			;yes, end of file found
	mov		dl, in_buffer		;no, load file character
	cmp		dl, 1ah   			;is it Control-Z <EOF>?
	jz 		eof     			;jump if yes
	mov		ah, 2     			;display character function
	int		21h      			;DOS call
	cmp		in_buffer, 10		;see if it is the end of line
	je		endline				;jump if it was end of line
	mov		out_buffer[di], dl	;save character in buffer
	mov		empty[di], ' '		;save for an empty file
	inc		di					;increment in_buffer index
	jmp		READFILE 			;and repeat
endline:						;this is if there was a new line
	mov		cx,	si				;get value of si
	imul	cx, 80				;move to end of line
	sub		cx, 1				;index format
	mov		di, cx
	mov		out_buffer[di], 10	;add new line in buffer
	mov		empty[di], 10		;add new line for empty
	inc		di					;next line in buffer
	inc		si					;add line count
	cmp		si, 26 				;line limit
	je		sizerror			;jump if it is less than or equal to 25
	jmp		READFILE 			;and repeat
readerror:
	;set video mode and clear screen
	mov     ah, 0				;set mode function
	mov     al, 3				;80x25 color text
	int     10h             	;set mode
	lea		dx, rmsg			;set up pointer to error message
	mov		ah, 9    			;display string function
	int		21h     			;DOS call
	stc		        			;set error flag
	ret
sizerror:
	;set video mode and clear screen
	mov     ah,0            	;set mode function
	mov     al,3            	;80x25 color text
	int     10h             	;set mode
	lea		dx, smsg			;set up pointer to error message
	mov  	ah, 9				;display string function
	int		21h					;DOS call
	stc							;set error flag
	ret
eof:							;now we want to fill the rest with endlines
	mov		cx,	si				;get value of si
	imul	cx, 80				;move to end of line
	sub		cx, 1				;index format
	mov		di, cx
fill:
	mov		out_buffer[di], 10	;add line
	mov		empty[di], 10		;add line to empty
	add		di, 80				;now we just keep jumping by 80
	inc		si					;add line count
	cmp		si, 24 				;line limit until line 25
	jle		fill
	ret
READFILE ENDP

;----------------------------------------WRITE FILE-----------------------
WRITEFILE PROC NEAR
	mov		di, 0				;counter for in_buffer
;move cursor to upper left corner
	mov     ah,2            	;move cursor function
	xor     dx,dx           	;position (0,0)
	mov     bh,0            	;page 0
	int     10h             	;move cursor
;get keystroke
	mov     ah,0            	;keyboard input function
	int     16h             	;ah=scan code, al = ascii code
inputloop:
;ctrl keys
	cmp		al, 5
	je		encrypt
	cmp		al, 14
	je		new
	cmp		al, 17
	je		quit
	cmp		al, 19
	je		save
;if function key
	cmp     al, 0           	;al = 0?
	jne     else_           	;no, character key
;then
	call    DO_FUNCTION     	;execute function
	jmp     nextkey				;get next keystroke
else_:
;backspace scenario
	cmp		al, 8				;check for backspace
	jne		write				;if not jump
	mov		al, ' '				;else replace with space
	mov		out_buffer[di], al	;save the value in the in_buffer
	;display character
	mov     ah, 2           	;display character func
	mov     dl, al          	;GET CHARACTER
	int     21h             	;display character
	;move cursor
	mov     ah,3            	;get cursor location
	mov     bh,0            	;on page 0
	int     10h             	;dh = row, dl = col
	dec		dl					;make sure it doesn't shift
	mov     ah,2            	;cursor move function
	int     10h             	;move cursor
	jmp		nextkey
write:
;save to handle when modified
	mov		out_buffer[di], al	;save the value in the in_buffer
	inc		di
	;display character
	mov     ah, 2           	;display character func
	mov     dl, al          	;GET CHARACTER
	int     21h             	;display character
;-------------------------------check end of line/file----------------------
	;locate cursor
	mov     ah,3            	;get cursor location
	mov     bh,0            	;on page 0
	int     10h             	;dh = row, dl = col
	;check end of line writing
	cmp		dl, 79				;compare to a end of line
	jl		nextkey				;if not, jump
	cmp		dh, 24
	jl		linemod
	dec		di					;make sure buffer index doesn't move
	mov		dl, 78				;make sure cursor doesn't move
	mov     ah,2            	;cursor move function
	int     10h             	;move cursor
	jmp		nextkey
linemod:						;check only for new line
	inc		di					;else skip the newline character
	;move cursor
	xor		dl, dl				;col = 0
	inc		dh					;row ++
	mov     ah,2            	;cursor move function
	int     10h             	;move cursor
nextkey:
	mov     ah,0            	;get keystroke function
	int     16h             	;ah=scan code,al=ASCII code
	jmp     inputloop
;--------------------------------encryption------------------------------
encrypt:
	mov 	di, 0				;used for counter
	;move cursor
	xor		dx, dx				;start cursor at 0, 0
	mov     ah,2            	;cursor move function
	int     10h             	;move cursor
shift_char:
	xor		ah, ah
	mov		al, out_buffer[di]	;get the character from buffer
	cmp		al, ' '				;don't encrypt empty lines
	je		skip
	cmp		al, 10				;don't encrypt new lines
	je		nl
	add		ax, 47				;shift
	cmp		ax, 127				;is it greater than available chars?
	jl		print				;if not jump
	sub		ax, 94				;else subtract (33 based system)
print:
	;display character
	mov     ah, 2           	;display character func
	mov     dl, al          	;GET CHARACTER
	int     21h             	;display character
	mov		out_buffer[di], al	;save to buffer
	mov     ah,3            	;get cursor location
	mov     bh,0            	;on page 0
	int     10h             	;dh = row, dl = col
	jmp		increment
nl:
	;move cursor
	inc		dh					;next line
	xor		dl, dl				;col = 0
	mov     ah, 2            	;cursor move function
	int     10h             	;move cursor
	jmp 	increment
skip:
	;move cursor
	inc		dl					;increment
	mov     ah,2            	;cursor move function
	int     10h             	;move cursor
increment:
	inc 	di
	cmp		di, 1999			;is it the last character?
	jne		shift_char			;if not, loop
	mov		di, 0				;reset location of buffer index
	;move cursor
	xor		dx, dx				;start cursor at 0, 0
	mov     ah,2            	;cursor move function
	int     10h             	;move cursor
	jmp		nextkey
;-----------------------------------new file----------------------------
new:
	; set position in file to top left corner
	mov		ax, 4200h 			;set cursor to the beginning of file
	mov		bx, handle
	xor		cx, cx
	xor		dx, dx
	int		21h
	;write in file
	mov		ah, 40h
	mov		bx, handle
	mov		cx, 1999			;do not include last line
    mov		dx, offset empty
    int		21h
	jc 		writerror   		;jump if error
	ret
;--------------------------------------quit----------------------------
quit:
	ret
;------------------------------------save------------------------------
save:
	; set position in file to top left corner
	mov		ax, 4200h 			;set cursor to the beginning of file
	mov		bx, handle
	xor		cx, cx
	xor		dx, dx
	int		21h
	;write in file
    mov		ah, 40h
	mov		bx, handle
	mov		cx, 1999			;do not include last line
    mov		dx, offset out_buffer
    int		21h
	jc 		writerror   		;jump if error
	ret
writerror:
	;set video mode and clear screen
	mov     ah, 0           	;set mode function
	mov     al, 3           	;80x25 color text
	int     10h             	;set mode
	lea		dx, wmsg			;set up pointer to error message
	mov		ah, 9				;display string function
	int		21h 				;DOS call
	stc							;set error flag
	ret
WRITEFILE ENDP

;---------------------------------CLOSE FILE--------------------------------
CLOSEFILE PROC NEAR
	mov     ah, 0           ;set mode function
	mov     al, 3           ;80x25 color text
	int     10h             ;set mode
	mov		ah, 3Eh			;close file with handle function
	mov		bx, handle		;load file handle
	int		21h		  		;DOS call
	jc 		closerror   	;jump if error
	ret
closerror:
	;set video mode and clear screen
	mov     ah, 0           ;set mode function
	mov     al, 3           ;80x25 color text
	int     10h             ;set mode
	lea		dx, cmsg		;set up pointer to error message
	mov		ah, 9			;display string function
	int		21h 			;DOS call
	stc						;set error flag
	ret
CLOSEFILE ENDP
	
;------------------------------------------CURSOR CONTROL-----------------------------
DO_FUNCTION:
; operates the arrow keys
; input: ah scan code
; output: none 
	push    bx
	push    cx
	push    dx
	push    ax              ;save scan code
;locate cursor
	mov     ah,3            ;get cursor location
	mov     bh,0            ;on page 0
	int     10h             ;dh = row, dl = col
	pop     ax              ;retrieve scan code
;case scan code of
	cmp     ah,72           ;up arrow?
	je      ucursor			;yes, execute
	cmp     ah,75           ;left arrow?
	je      lcursor			;yes, execute
	cmp     ah,77  			;right arrow?
	je      rcursor			;yes, execute
	cmp     ah,80  			;down arrow?
	je      dcursor			;yes, execute
	jmp     return          ;other function key
ucursor:
	cmp     dh,0            ;row 0?
	je		execute
	dec     dh              ;no, row = row - 1
	sub		di, 80
	jmp     execute         ;go to execute
dcursor:
	cmp     dh,24           ;last row?
	je      execute         ;yes, just execute
	inc     dh              ;no, row = row + 1
	add		di, 80
	jmp     execute         ;go to execute
lcursor:
	cmp     dl,0     		;column 0?
	jne     lmove    		;no, move to left
	cmp     dh,0     		;row 0?
	je      execute  		;yes, just execute
	dec     dh              ;row = row - 1
	sub		di, 80
	mov     dl, 78          ;last column 
	jmp     execute         ;go to execute
rcursor:
	cmp     dl, 78           ;last column?
	jne     rmove        	;no, move to right
	cmp     dh,24           ;last row?
	je      execute       	;yes, just execute
	inc     dh              ;row = row + 1
	add		di, 80			;go 1 line down
	mov     dl,0            ;col = 0
	jmp     execute         ;go to execute
lmove:
	dec     dl              ;col = col - 1
	dec		di				;1 line left
	jmp     execute         ;go to execute
rmove:
	inc     dl              ;col = col + 1
	inc		di				;1 line right
	jmp     execute         ;go to execute
execute:
	mov     ah,2            ;cursor move function
	int     10h             ;move cursor
return:
	pop     dx
	pop     cx
	pop     bx
	ret	
	
end start
