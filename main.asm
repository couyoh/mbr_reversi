bits 16
org 0x7c00

%define MAX_X 8
%define MAX_Y 8
%define EMPTY '.'
%define USER1 '1'
%define USER2 '2'
%define NEWLINE_0D 0x0d
%define NEWLINE_0A 0x0a

; If I use subroutine call instead of macro, compiled code is bigger size.
%macro get_nbit 2
    mov %1, %2
    shr %1, cl
    and %1, 1
%endmacro
; FYR: subroutine call
; get_nbit:
;     mov bp, sp
;     xor ax, ax
;     push cx
;     mov cx, [bp + 4]
;     mov ax, [bp + 2]
;     shr al, cl
;     and al, 1
;     pop cx
;     ret 4
%macro set_nbit 2
    mov al, 1
    shl al, %2
    or %1, al
%endmacro
%macro unset_nbit 2
    mov al, 1
    shl al, %2
    not al
    and %1, al
%endmacro

       ; hgfedcba
map db 0b00000000, ; 1
    db 0b00000000, ; 2
    db 0b00000000, ; 3
    db 0b00010000, ; 4
    db 0b00001000, ; 5
    db 0b00000000, ; 6
    db 0b00000000, ; 7
    db 0b00000000  ; 8

               ; hgfedcba
map_enabled db 0b00000000, ; 1
            db 0b00000000, ; 2
            db 0b00000000, ; 3
            db 0b00011000, ; 4
            db 0b00011000, ; 5
            db 0b00000000, ; 6
            db 0b00000000, ; 7
            db 0b00000000  ; 8

init:
    xor ax, ax
    mov al, 3
    int 0x10
    jmp loop

putchar:
    mov bp, sp
    pusha
    mov ax, [bp + 2]
    mov ah, 0xe
    xor bx, bx
    int 0x10
    popa
    ret 2

print_0d0a:
    push NEWLINE_0D
    call putchar
    push NEWLINE_0A
    call putchar
    ret

draw:
    xor dx, dx
    xor bx, bx
    .title:
        cmp dx, MAX_X
        jz .x
        mov ax, dx
        add ax, 'a'
        push ax
        call putchar
        inc dx
        jmp .title
    .x:
        call print_0d0a
        cmp bx, MAX_X
        jz .end_x
        mov al, [map_enabled+bx]
        mov ah, [map+bx]
        xor cx, cx
        .y:
            cmp cl, MAX_Y
            jz .end_y
            ; check whether the piece is placed
            get_nbit dl, al
            test dl, dl
            jz .print_empty

            ; check whose piece
            get_nbit dh, ah
            test dh, dh
            jz .print_USER1
            push byte USER2
            jmp .putchar
            .print_USER1:
                push byte USER1
            .putchar:
                call putchar
                jmp .next_y
            .print_empty:
                push byte EMPTY
                call putchar
            .next_y:
                inc cx
                jmp .y
        .end_y:
            mov dx, bx
            add dx, '1'
            push dx
            call putchar
            inc bx
            jmp .x
    .end_x:
        ret

detect_position:
    pusha
    xor bx, bx
    xor cx, cx
    call wait_key ; x must be between a and h
    mov cl, al
    sub cl, 'a'
    call wait_key ; y must be between 1 and 8
    mov bl, al
    sub bl, '1'
    call print_0d0a

    ; check whether empty piece
    get_nbit dl, [map_enabled+bx]
    test dl, dl
    jnz .end ; piece is not empty
    push cx
    xor dx, dx
    .plus:
        inc cl
        cmp cl, MAX_X
        jge .minus
        get_nbit al, [map_enabled+bx]
        test al, al
        jz .minus_init
        get_nbit al, [map+bx]
        cmp al, [player]
        jz .minus_init
        inc dl ; number of same pieces (+x direction)
        jmp .plus
    .minus_init:
        pop cx
        push cx
    .minus:
        dec cl
        cmp cl, 0 ; I wouldn't use "test cl, cl" because cl might be negative.
        jle .change_piece
        get_nbit al, [map_enabled+bx]
        test al, al
        jz .change_piece
        get_nbit al, [map+bx]
        cmp al, [player]
        jz .minus_init
        inc dh ; number of same pieces (-x direction)
        jmp .minus
    .change_piece:
        ; if no same pieces, don't put piece
        test dx, dx
        jz .end
        pop cx
        push cx
        mov ch, cl
        add dl, cl
        add dh, cl
        .positive_loop:
            cmp cl, dl
            jz .negative
            mov al, 1
            shl al, cl
            xor [map+bx], al
            inc cl
            jmp .positive_loop
        .negative:
            pop cx
            push cx
        .negative_loop:
            cmp cl, dh
            jle .enable_peace
            mov al, 1
            shl al, cl
            xor [map+bx], al
            dec cl
            jmp .negative_loop
    .enable_peace:
        ; put piece
        pop cx
        set_nbit [map_enabled+bx], cl
        mov dl, [player]
        test dl, dl
        jz .enable_player1
        set_nbit [map+bx], cl
        jmp .toggle_player
        .enable_player1:
            unset_nbit [map+bx], cl
        .toggle_player:
            xor dl, 1
            mov [player], dl
    .end:
        popa
        ret

wait_key:
    xor ax, ax
    int 0x16
    push ax ; for pop
    push ax ; for putchar's argument
    call putchar
    pop ax
    ret

loop:
    call draw
    call detect_position
    jmp loop

player db 0

times 510-($-$$) db 0
db 0x55, 0xaa
