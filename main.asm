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

%macro abs 2
    sub %1, %2
    neg %1
%endmacro

%macro DEBUG 0
    xchg bx, bx
%endmacro

player db 0

               ; hgfedcba
map_enabled db 0b00000000, ; 1
            db 0b00000000, ; 2
            db 0b00000000, ; 3
            db 0b00011000, ; 4
            db 0b00011000, ; 5
            db 0b00000000, ; 6
            db 0b00000000, ; 7
            db 0b00000000  ; 8

       ; hgfedcba
map db 0b00000000, ; 1
    db 0b00000000, ; 2
    db 0b00000000, ; 3
    db 0b00010000, ; 4
    db 0b00001000, ; 5
    db 0b00000000, ; 6
    db 0b00000000, ; 7
    db 0b00000000  ; 8


init:
    mov ax, 3
    int 0x10
    .loop:
        call draw
        call main
        jmp .loop

putchar:
    pusha
    mov ah, 0xe
    xor bx, bx
    int 0x10
    popa
    ret

rotate90:
    lea si, [map_enabled]
    call ._rotate90
    lea si, [si+8]
    call ._rotate90
    xchg cx, bx
    abs bx, MAX_X-1
    ret

    ._rotate90:
        pusha
        xor cx, cx
        .outer_loop:
            cmp cx, MAX_X
            jz .end

            xor ax, ax
            xor bx, bx
            .inner_loop:
                cmp bx, MAX_Y
                jz .outer_next
                bt [si+bx], cx
                jnc .finally
                bts ax, bx
                .finally:
                    inc bx
                    jmp .inner_loop

            .outer_next:
                push ax
                inc cx
                jmp .outer_loop
        .end:
            xor bx, bx
            .loop:
                cmp bx, MAX_Y
                jz .ret
                pop ax
                mov [si+bx], al
                inc bx
                jmp .loop
            .ret:
                popa
                ret

askew:
    push cx
    lea si, [map_enabled]
    call ax
    xor ax, ax
    xor di, di
    .loop:
        cmp bx, MAX_Y
        jge .end
        cmp cx, MAX_Y
        jge .end
        bt [si+bx+8], cx
        jnc .si_check
        bts di, cx
        .si_check:
            bt [si+bx], cx
            jnc .next
            bts ax, cx
        .next:
            inc bx
            inc cx
            jmp .loop
    .end:
        pop cx
    .ret:
        ret
    .find_start:
        sub bx, cx
        jc .set_cx
        mov cx, di
        ret
        .set_cx:
            sub cx, bx
            mov bx, di
            ret
    .plus:
        abs cx, 7
        mov di, 7
        call .find_start
        ret

print_0d0a:
    mov al, NEWLINE_0D
    call putchar
    mov al, NEWLINE_0A
    call putchar
    ret

draw:
    xor ax, ax
    xor bx, bx
    .title:
        cmp ax, MAX_X
        jz .x
        push ax
        add ax, 'a'
        call putchar
        pop ax
        inc ax
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
            bt [map_enabled+bx+8], cx
            jnc .print_USER1
            mov al, USER2
            jmp .putchar
            .print_USER1:
                mov al, USER1
                jmp .putchar
            .print_empty:
                mov al, EMPTY
            .putchar:
                call putchar
                inc cx
                jmp .y
        .end_y:
            mov dx, bx
            add dx, '1'
            mov ax, dx
            call putchar
            inc bx
            jmp .x
    .end_x:
        ret

main:
    call wait_key ; x must be between a and h
    movzx cx, al
    sub cl, 'a'
    call wait_key ; y must be between 1 and 8
    movzx bx, al
    sub bl, '1'
    call print_0d0a

    xor dx, dx ; will be changed at change_piece
    call .change_piece
    call rotate90
    call .change_piece

    ; rotate90 overwrites map_enabled and map.
    ; That's why it calls rotate90 multiple times.
    call rotate90 ; 180
    call rotate90 ; 240
    call rotate90 ; 360

    push bx
    xor di, di
    mov ax, askew.find_start
    call askew
    xchg si, ax
    pop bx
    push .inc_sidi
    call change_piece

    push bx
    mov ax, askew.plus
    call askew
    xchg si, ax
    pop bx
    ; push .inc_sidi
    ; call change_piece

    test dx, dx
    jz .end
    call .make_sidi
    xchg ax, cx
    call change_piece.set
    xor byte [player], 1 ; toggle player
    .end:
        ret
    .inc_sidi:
        push bx
        push cx
        xor di, di
        call askew.find_start
        add bx, ax
        call .make_sidi
        pop cx
        pop bx
        ret
    .make_sidi:
        lea si, [map_enabled+bx]
        lea di, [si+8]
        ret
    .change_piece:
        call .make_sidi
        mov si, [si]
        mov di, [di]
        push .make_sidi
        call change_piece
        ret

change_piece:
    mov bp, sp
    call count_piece
    .loop:
        inc ax
        cmp ax, cx
        jge .ret
        inc dx ; player change flag
        call [bp + 2]
        call .set
        jmp .loop
    .ret:
        ret 2
    .set:
        cmp byte [player], 0
        jnz .set_player2
        .set_player1:
            btr [di], ax
            jmp .next
        .set_player2:
            bts [di], ax
        .next:
            bts [si], ax
        ret

count_piece:
    push bx
    xor bx, bx
    call .find
    push ax
    inc bx
    call .find
    pop cx
    pop bx
    ret
    .find:
        mov ax, cx
        .loop:
            test bx, bx
            jz .inc
            .dec:
                dec ax
                jmp .check_enabled
            .inc:
                inc ax
            .check_enabled:
                cmp ax, 0
                jl .end
                cmp ax, MAX_X
                jg .end
                bt si, ax
                jnc .end
            .check:
                bt di, ax
                push dx
                get_cf dx
                cmp dl, [player]
                pop dx
                jnz .loop
                ret
        .end:
            mov ax, cx
            ret

wait_key:
    xor ax, ax
    int 0x16
    call putchar
    ret

times 510-($-$$) db 0
db 0x55, 0xaa
