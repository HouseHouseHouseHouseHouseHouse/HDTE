; ========================================================================
; House-DOS Text Editor
;
; Written by The House-DOS Developers
; ========================================================================

    BITS 16

; ========================================================================
; Header
; ========================================================================

header:
    jmp main                            ; Don't execute the header

h_creator       dw creator              ; Creator string
h_desc          dw desc                 ; Description string
h_usage         dw usage                ; Usage string


; ========================================================================
; MAIN ROUTINE
; ========================================================================

main:
    mov ah, 0x28                        ; Load file from first parameter
    int 0x7E

    jc .done                            ; If failed, we're done

    mov ah, 0x20                        ; Otherwise, get the parameter
    mov cx, 0x0000                      ; First parameter
    mov di, fname                       ; Our filename buffer
    int 0x7E

    mov ah, 0x70                        ; Get size of file
    int 0x7E

    mov word [fsize], ax                ; Store size here

    mov ah, 0x0F                        ; Modify interface config
    mov al, 0x03                        ; Turn off error messages and commentary
    int 0x7E

.load:
    call draw_header                    ; Print header
    mov cx, 0x17                        ; Get and print 23 lines

.print:
    push cx                             ; Store line counter

    mov ah, 0x64                        ; Get line
    neg cx                              ; Negate cx
    add cx, 0x17                        ; Add 23 to get line index
    add cx, word [linecounter]          ; Add what line we're on
    mov di, dest_buffer                 ; Copy into buffer
    int 0x7E

    jc .set_cursor                      ; Everything is loaded

    mov ah, 0x10                        ; Print bytes
    mov si, dest_buffer                 ; Print from our buffer
    mov cx, di
    sub cx, si                          ; How many bytes in this line
    int 0x7E

.nextline:
    pop cx                              ; Restore line counter
    loop .print                         ; Go to next line

.set_cursor:
    mov ah, 0x08                        ; Set cursor position
    mov dx, 0x0100                      ; The upper-left corner (avoid the header)
    int 0x7E

    mov ah, 0x65                        ; Get line address
    mov cx, word [linecounter]          ; The starting line on screen
    int 0x7E

    mov ah, 0x62                        ; Get bytes starting from that point
    mov cx, word [address]              ; Print bytes of how far into the file
    sub cx, si                          ; Minus the bytes offscreen
    mov di, dest_buffer
    int 0x7E

    mov ah, 0x10                        ; Print bytes
    mov si, dest_buffer                 ; Print from our buffer
    int 0x7E

.edit:
    mov ah, 0x0D                        ; Get cursor position
    int 0x7E

    mov ah, 0x12                        ; Get keypress
    int 0x7E

    jc .edit                            ; Loop if no keypress

    cmp ah, 0x01                        ; Is it an escape?
    je .escape_menu

    cmp ah, 0x0E                        ; Backspace
    je .backspace

    cmp ah, 0x53                        ; Delete key
    je .delete

    cmp ah, 0x4B                        ; Left arrow
    je .left_arrow

    cmp ah, 0x4D                        ; Right arrow
    je .right_arrow

    cmp ah, 0x48                        ; Up arrow
    je .up_arrow

    cmp ah, 0x50                        ; Down arrow
    je .down_arrow

    cmp ah, 0x1C                        ; RETURN to write newline
    je .newline

    cmp ah, 0x3B                        ; F1 to cut
    je .line_cut

    cmp ah, 0x3C                        ; F2 to copy
    je .line_copy

    cmp ah, 0x3D                        ; F3 to paste
    je .line_paste

    cmp ah, 0x3E                        ; F4 to delete line
    je .line_delete

    cmp ah, 0x42                        ; F8 to save
    je .save

    cmp al, 0x00                        ; Is there no ASCII code?
    je .edit                            ; If so, loop

    mov byte [char_write], al           ; Otherwise, save the character to write

    mov ah, 0x6B                        ; Insert byte
    mov di, word [address]              ; Our position
    mov cx, 0x01                        ; Write 1 byte
    mov si, char_write                  ; Address of our character
    int 0x7E

    inc word [address]                  ; Move 1 character forward
    inc word [fsize]                    ; Increase file size by 1 character

    jmp .load


    ;cmp
    ; If they press enter, insert a newline
    ; F1: Cut
    ; F2: Copy
    ; F3: Paste
    ; F4: Delete
    ; F8: Save

    ; Display cursor
    ; Check keyboard input
    ; If arrow keys, move cursor
    ; If normal keys, add to file where cursor is
    ; If backspace/delete, remove from file
    ; If enter, insert new line
    ; If escape character, display special options/prompts
    ; If quit character, leave

.escape_menu:
    call draw_header                    ; Print header
    mov ah, 0x02                        ; Print line
    mov si, menu_text                   ; Escape menu text
    int 0x7E

.escape_loop:
    mov ah, 0x12                        ; Get keypress
    int 0x7E

    jc .escape_loop                     ; Loop if no keypress

    cmp ah, 0x01                        ; Is it escape again?
    je .done                            ; If so, quit

    jmp .load                           ; Print file again, then resume editing

.backspace:
    mov ah, 0x6B                        ; Insert bytes (shift left)
    mov cx, 0xFFFF                      ; Shift 1 left (delete 1 character)
    mov di, word [address]              ; Shift starting from here
    int 0x7E

    dec word [address]                  ; Move cursor back one
    dec word [fsize]                    ; Decrement file size

    jmp .load                           ; Print edited version

.delete:
    mov ax, word [address]              ; Our position in the file
    inc ax                              ; We don't want to ever be on the last character

    cmp ax, word [fsize]                ; Are we at the end of the file?
    jnb .edit                           ; If so, do nothing

    mov ah, 0x6B                        ; Insert bytes (shift left)
    mov cx, 0xFFFF                      ; Shift one left
    mov di, word [address]              ; Shift starting from here
    inc di                              ; Delete character to the right
    int 0x7E

    dec word [fsize]                    ; Decrement file size

    jmp .load                           ; Print edited version

.newline:
    mov di, word [address]              ; Get our address
    mov ah, 0x6B                        ; Insert bytes
    mov cx, 0x01                        ; Write 1 byte
    mov si, newline_char                ; We want to write a newline
    int 0x7E

    inc word [address]                  ; Move 1 character forward
    inc word [fsize]                    ; Increase file size by 1 character

    jmp .load                           ; Print edited version

.left_arrow:
    cmp word [address], 0x0000          ; Are we at the beginning of the file?
    je .edit                            ; If so, do nothing

    dec word [address]                  ; Otherwise, move address back 1
    jmp .set_cursor                     ; Update cursor position

.right_arrow:
    mov ax, word [address]              ; Our position in the file
    inc ax                              ; We don't want to ever be on the last character

    cmp ax, word [fsize]                ; Are we at the end of the file?
    jnb .edit                           ; If so, do nothing

    inc word [address]                  ; Move address forward 1
    jmp .set_cursor                     ; Update cursor position

.up_arrow:
    mov ah, 0x67                        ; Get line and col
    mov si, word [address]              ; Our address in the file
    int 0x7E

    cmp cx, 0x0000                      ; Are we on the first line?
    je .edit                            ; Id so, do nothing

    mov bx, word [address]              ; Our address
    sub bx, dx                          ; Subtract col number to get address of our line
    dec bx                              ; Avoid those O.B.O.Es
    push bx                             ; Save the address of the start of our line

    mov ah, 0x65                        ; Get address of a line
    dec cx                              ; Line above us
    int 0x7E

    mov word [address], si              ; Go to start of line above us
    add word [address], dx              ; Add our column number

    sub bx, si                          ; Subtract to get length of line above us
    inc dx                              ; Avoid an O.B.O.E
    cmp bx, dx                          ; Is the line above us shorter than our col?

    pop bx                              ; Restore address of start of our line
    jae .set_cursor                     ; If not, proceed

    mov word [address], bx              ; Otherwise, set our address to this
    jmp .set_cursor                     ; Proceed

.down_arrow:
    mov ah, 0x67                        ; Get line and col
    mov si, word [fsize]                ; Get the address of the file size
    dec si                              ; Avoid an O.B.O.E
    int 0x7E

    push cx                             ; Preserve the row number

    mov si, word [address]              ; Our address in the file
    int 0x7E

    pop bx                              ; Restore the last row
    cmp cx, bx                          ; Are we on the last row?
    jnb .edit                           ; If so, do nothing

    mov bx, word [address]              ; Our address
    sub bx, dx                          ; Subtract col number to get address of our line
    dec bx                              ; Avoid those O.B.O.Es

    mov ah, 0x65                        ; Get address of a line
    inc cx                              ; Line below us
    int 0x7E

    mov word [address], si              ; Go to start of line below us
    add word [address], dx              ; Add our column number (go straight down)

    push cx                             ; Preserve line number

    mov ah, 0x67                        ; Convert address to line/col numbers
    mov si, word [address]              ; Our current address
    int 0x7E

    pop bx                              ; Restore line below us
    cmp cx, bx                          ; Is our address on the next line?
    je .set_cursor

    mov ah, 0x65                        ; Get address of line
    mov cx, bx                          ; Line number
    inc cx                              ; 2 lines below us
    int 0x7E

    dec si                              ; Go one character back
    mov word [address], si              ; Go to this address
    jmp .set_cursor

.line_cut:
    mov ah, 0x67                        ; Get line/col from address
    mov si, word [address]              ; Our current address
    int 0x7E

    push cx                             ; Save line number

    mov ah, 0x64                        ; Get line
    mov di, line_storage                ; Our buffer
    int 0x7E

    call get_line_length                ; Get the length of this line
    mov word [cline_length], si         ; Store here

    pop cx                              ; Restore line number
    call delete_line                    ; Now delete the line

    jmp .load                           ; Print edited version

.line_copy:
    mov ah, 0x67                        ; Get line/col from address
    mov si, word [address]              ; Our current address
    int 0x7E

    mov ah, 0x64                        ; Get line
    mov di, line_storage                ; Our buffer
    int 0x7E

    call get_line_length                ; Get the length of this line
    mov word [cline_length], si         ; Store here

    jmp .load                           ; Print edited version

.line_paste:
    mov ah, 0x67                        ; Get line/col from address
    mov si, word [address]              ; Our current address
    int 0x7E

    mov ah, 0x6D                        ; Insert line
    mov si, line_storage                ; From buffer (what's been copied)
    int 0x7E

    mov ax, word [cline_length]         ; Store length of line that's being pasted
    add word [fsize], ax                ; Increase file size by this much

    jmp .load                           ; Print edited version

.line_delete:
    mov ah, 0x67                        ; Get line and col
    mov si, word [address]              ; Our address in the file
    int 0x7E

    call delete_line                    ; Use the routine

    jmp .load                           ; Print edited version

.save:
    mov ah, 0x6F                        ; Write file to disk
    mov si, fname                       ; File name
    mov cx, word [fsize]                ; File size
    int 0x7E

    jc .done                            ; Done if there's an error

    jmp .load                           ; Return to editing

.done:
    mov ah, 0xFF                        ; End command
    int 0x7E


draw_header:
    pusha                               ; Save register states

    mov ah, 0x06                        ; Clear screen
    int 0x7E

    mov ah, 0x11                        ; Draw block
    mov al, 0x20                        ; Spaces
    mov bl, 0b10010000                  ; Blinking, blue background, black foreground
    mov cx, 0x0050                      ; The length of one row
    mov dx, 0x0000                      ; Uppermost row, leftmost col
    int 0x7E

    mov ah, 0x02                        ; Print line
    mov si, headermsg                   ; Our message
    int 0x7E

    popa                                ; Restore register states
    ret                                 ; Return to caller


delete_line:                            ; Delete whatever line is in CX
    pusha                               ; Save register states to stack

    mov ah, 0x65                        ; Get line address
    int 0x7E

    mov word [address], si              ; This will be our new cursor position
    push si                             ; Preserve address

    inc cx                              ; Next line
    int 0x7E

    pop cx                              ; Restore address
    sub cx, si                          ; Subtract to get negative length of line (negated, to shift left)

    mov ah, 0x6B                        ; Insert bytes (shift left)
    mov di, si                          ; Shift starting from next line
    int 0x7E

    add word [fsize], cx                ; Add negative length of line to file length

    popa                                ; Restore register states
    ret                                 ; Return to caller


get_line_length:                        ; Get length of the line in CX
    mov ah, 0x65                        ; Get line address
    int 0x7E

    push si                             ; Preserve this address

    inc cx                              ; Go to next line
    int 0x7E

    pop cx                              ; Restore address
    sub si, cx                          ; Subtract to get length of line
    mov cx, si                          ; Put length in cx

    ret                                 ; Return to caller


data:

headermsg       db "House-DOS Text Editor", 0x00

fname           dq 0x0000000000000000
                dd 0x00000000
fsize           dw 0x0000

linecounter     dw 0x0000               ; Nearest 23 lines
address         dw 0x0000               ; Address of where we are

cline_length    dw 0x0000               ; Length of line that's been copied or cut

newline_char    db 0x0A
char_write      db 0x00

menu_text       db "Commands:", 0x0A, "F1: Cut line", 0x0A, "F2: Copy line", 0x0A, "F3: Paste line", 0x0A, "F4: Delete line", 0x0A, "F8: Save", 0x0A
                db "Press ESC to exit, any other key to return...", 0x00
save_message    db "File saved!", 0x00
editing_message db "Editing file", 0x00

creator         db "Ben and Jacob", 0x00
desc            db "A text editor for the House-DOS platform.", 0x00
usage           db "EDIT <FILENAME>", 0x00

line_storage:
times 0x50      db 0x00

dest_buffer: