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

loop:
    call draw
    call detect_position
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

rotate90:
    push dx
    lea si, [map_enabled]
    call ._rotate90
    lea si, [map]
    call ._rotate90
    xchg cx, bx
    abs bx, MAX_X-1
    pop dx
    ret

    ._rotate90:
        ; mov bp, sp
        pusha
        ; mov si, [bp + 2]
        xor cx, cx
        mov ax, si
        .outer_loop:
            cmp cx, MAX_X
            jz .end

            xor dx, dx
            xor di, di
            .inner_loop:
                cmp dx, MAX_Y
                jz .outer_next
                bt [si], cx
                jnc .finally
                bts di, dx
                .finally:
                    inc dx
                    inc si
                    jmp .inner_loop

            .outer_next:
                mov si, ax
                push di
                inc cx
                jmp .outer_loop
        .end:
            xor cx, cx
            .loop:
                cmp cx, MAX_Y
                jz .ret
                pop ax
                mov [si], al
                inc si
                inc cx
                jmp .loop
            .ret:
                popa
                ; ret 2
                ret

askew:
    ; si: map_enabled
    ; di: map
    ; bx: y
    ; cx: x
    xor ax, ax
    xor dx, dx
    push bx
    push cx
    .find_start:
        dec bx
        jl .set_zero_bx
        dec cx
        jl .set_zero_cx
        test bx, bx
        jz .loop
        test cx, cx
        jz .loop
        jmp .find_start
    .set_zero_bx:
        xor bx, bx
        jmp .loop
    .set_zero_cx:
        xor cx, cx
    .loop:
        cmp bx, MAX_Y
        jge .end
        cmp cx, MAX_Y
        jge .end
        bt [di+bx], cx
        jnc .si_check
        bts dx, cx
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
        pop bx
        ret

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
                jmp .putchar
            .print_empty:
                push byte EMPTY
                jmp .putchar
            .putchar:
                call putchar
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
    call wait_key ; x must be between a and h
    movzx cx, al
    sub cl, 'a'
    call wait_key ; y must be between 1 and 8
    movzx bx, al
    sub bl, '1'
    call print_0d0a

    lea si, [map_enabled+bx]
    lea di, [map+bx]
    xor dx, dx

    call change_piece
    call rotate90 ; bx will be changed
    lea si, [map_enabled+bx]
    lea di, [map+bx]
    call change_piece

    ; rotate90 overwrites map_enabled and map.
    ; That's why it calls rotate90 multiple times.
    call rotate90 ; 180
    call rotate90 ; 240
    call rotate90 ; 360

    pusha
    lea si, [map_enabled]
    lea di, [map]
    call askew
    xchg si, ax
    xchg di, dx
    call count_piece
    popa

    test dx, dx
    jz .end
    xor byte [player], 1 ; toggle player
    .end:
        ret

change_piece:
    push bx
    push cx
    call count_piece
    .loop:
        inc ax
        cmp ax, bx
        jge .done
        mov dx, 1 ; player change flag
        cmp byte [player], 0
        jnz .set_player2
        .set_player1:
            btr [di], ax
            btr [di], cx
            jmp .next
        .set_player2:
            bts [di], ax
            bts [di], cx
        .next:
            bts [si], ax
            bts [si], cx
            jmp .loop
    .done:
        pop cx
        pop bx
        ret

count_piece:
    xor bx, bx
    call .find
    push ax
    mov bx, 1
    call .find
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
                bt [si], ax
                jnc .end
            .check:
                bt [di], ax
                push dx
                get_cf dx
                ; xchg bx, bx
                cmp dx, [player]
                pop dx
                jnz .loop
                ret
        .end:
            mov ax, cx
            ret

wait_key:
    xor ax, ax
    int 0x16
    push ax
    call putchar
    ret

times 510-($-$$) db 0
db 0x55, 0xaa
