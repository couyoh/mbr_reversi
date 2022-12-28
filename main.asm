bits 16
org 0x7c00

%define MAX_X 8
%define MAX_Y 8
%define EMPTY '.'
%define USER1 '1'
%define USER2 '2'
%define NEWLINE_0D 0x0d
%define NEWLINE_0A 0x0a

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
            mov dl, al
            shr dl, cl
            and dl, 1
            test dl, dl
            jz .print_empty

            ; check whose piece
            mov dh, ah
            shr dh, cl
            and dh, 1
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
    call wait_key ; x
    mov cl, al ; must be between a and h
    sub cl, 'a'
    call wait_key ; y
    mov bl, al ; must be between 1 and 8
    sub bl, '1'
    call print_0d0a

    ; check whether empty piece
    mov dl, [map_enabled+bx]
    shr dl, cl
    test dl, dl
    jnz .end ; piece is not empty
    ; push cx
    .loop:
        cmp cl, MAX_X
        jz .end
        mov dl, [map+bx]
        shr dl, cl

        cmp dl, player
        jz .check_enabled
        jmp .loop
    .check_enabled:
        mov dl, [map_enabled+bx]
        shr dl, cl
        test dl, dl
        jz .end
        inc cx
        ; pop cx
        jmp .put_piece
    .put_piece:
        mov dl, 1
        shl dl, cl
        mov [map_enabled+bx], dl

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
