bits 16
org 0x7c00

%define MAX_X 8
%define MAX_Y 8
%define EMPTY '.'
%define USER1 'O'
%define USER2 'X'
%define NEWLINE_0D 0x0d
%define NEWLINE_0A 0x0a

%macro get_cf 1
    sbb %1, %1
    and %1, 1
%endmacro

player db 0

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
    mov ax, 3
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
        xor cx, cx
        .y:
            cmp cl, MAX_Y
            jz .end_y
            ; check whether the piece is placed
            bt [map_enabled+bx], cx
            jnc .print_empty

            ; check whose piece
            bt [map+bx], cx
            jnc .print_USER1
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
    call wait_key ; x must be between a and h
    movzx cx, al
    sub cl, 'a'
    call wait_key ; y must be between 1 and 8
    movzx bx, al
    sub bl, '1'
    call print_0d0a

    push cx
    ; check whether empty piece
    bt [map_enabled+bx], cx
    jc .end ; piece is not empty
    xor dx, dx
    ; Maybe I can use BSF/BSR instruction.
    .plus:
        inc cl
        cmp cl, MAX_X
        jge .end
        bt [map_enabled+bx], cx
        jnc .clear_dl
        bt [map+bx], cx
        get_cf al
        cmp al, [player]
        jz .minus_init
        inc dl ; number of same pieces (+x direction)
        jmp .plus
    .clear_dl:
        xor dl, dl
    .minus_init:
        pop cx
        push cx
    .minus:
        dec cl
        cmp cl, 0 ; I wouldn't use "test cl, cl" because cl might be negative.
        jle .end
        bt [map_enabled+bx], cx
        jnc .clear_dh
        bt [map+bx], cx
        get_cf al
        cmp al, [player]
        jz .change
        inc dh ; number of same pieces (-x direction)
        jmp .minus
    .clear_dh:
        xor dh, dh
    .change:
        ; if no same pieces, don't put piece
        test dx, dx
        jz .end
        pop cx
        push cx
        add dl, cl
        sub dh, cl
        neg dh
        .positive_loop:
            cmp cl, dl
            jg .negative
            cmp byte [player], 0
            jz .set_player1
            bts [map+bx], cx
            jmp .finally
            .set_player1:
                btr [map+bx], cx
            .finally:
                inc cl
                jmp .positive_loop
        .negative:
            pop cx
            push cx
        .negative_loop:
            cmp cl, dh
            jl .put
            cmp byte [player], 0
            jz .set_player1_
            bts [map+bx], cx
            jmp .finally_
            .set_player1_:
                btr [map+bx], cx
            .finally_:
            dec cl
            jmp .negative_loop
    .put:
        pop cx
        push cx
        bts [map_enabled+bx], cx
        mov dl, [player]
        test dl, dl
        jz .enable_player1
        bts [map+bx], cx
        jmp .toggle_player
        .enable_player1:
            btr [map+bx], cx
        .toggle_player:
            xor dl, 1
            mov [player], dl
    .end:
        pop cx
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

times 510-($-$$) db 0
db 0x55, 0xaa
