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

x_to_y:
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
    ; si: First address
    ; bx: y
    ; cx: x
    mov bp, sp
    pusha
    xor di, di
    .find_start:
        dec bx
        dec cx
        cmp bx, 0
        cmp cx, 0
        jle .loop ; jump if bx OR cx is zero.
        jmp .find_start
    .loop:
        cmp cx, MAX_Y
        jz .end
        bt [si+bx], cx
        jnc .finally
        bts di, cx
        .finally:
            inc bx
            inc cx
            jmp .loop
    .end:
        mov [bp - 2], di
        popa
        mov ax, [bp - 2]
        ret

check_piece:
    push cx
    push dx
    xor ax, ax
    push cx
    .dec_loop:
        mov ah, cl
        dec cl
        cmp cl, 0
        jl .loop_init
        bt [si], cx
        jnc .loop_init
        bt [di], cx
        get_cf dx
        cmp dx, [player]
        jnz .dec_loop
    .loop_init:
        pop cx
    .inc_loop:
        mov al, cl
        inc cl
        cmp cl, MAX_X
        jge .end
        bt [si], cx
        jnc .end
        bt [di], cx
        get_cf dx
        cmp dx, [player]
        jnz .inc_loop
    .end:
        pop dx
        pop cx
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
    call wait_key ; x must be between a and h
    movzx cx, al
    sub cl, 'a'
    call wait_key ; y must be between 1 and 8
    movzx bx, al
    sub bl, '1'
    call print_0d0a

    ; If input coord is not empty, do nothing.
    bt [map_enabled+bx], cx
    jc .end

    call detect_loop
    push ax
    call to_xy ; 90
    call detect_loop
    pop bx
    test ax, bx ; check whether are ax AND bx zero
    jz .end
    xor byte [player], 1 ; toggle player

    .end:
    call to_xy ; 180
    call to_xy ; 240
    call to_xy ; 360
    ; bx, cx has already been defined at to_xy subroutine.
    ; lea si, [map]
    ; call askew
    ; push ax
    ; lea si, [map_enabled]
    ; call askew
    ; mov si, ax
    ; pop di
    ; call check_piece
    ; xchg bx, bx
    ; cmp ah, al
    ; jz .end
    ; mov cx, ax
    ; .loop:
    ;     cmp ch, cl
    ;     movzx ax, ch
    ;     jg .end
    ;     cmp byte [player], 0
    ;     mov bx, ax
    ;     jz .set_player2
    ;     .set_player1:
    ;         btr [map+bx], ax
    ;         jmp .next
    ;     .set_player2:
    ;         bts [map+bx], ax
    ;     .next:
    ;         bts [map_enabled+bx], ax
    ;         inc ch
    ;         jmp .loop
    ; .end:
        ret

to_xy:
    lea si, [map_enabled]
    call x_to_y
    lea si, [map]
    call x_to_y
    xchg cx, bx
    abs bx, MAX_X-1
    movzx bx, bl
    ret

detect_loop:
    lea si, [map_enabled+bx]
    lea di, [map+bx]
    xchg bx, bx
    call check_piece

    ; If no same piece, do nothing.
    cmp ah, al
    jz .end

    mov cx, ax
    .loop:
        cmp ch, cl
        movzx ax, ch
        jg .toggle_player
        cmp byte [player], 0
        jnz .set_player2
        .set_player1:
            btr [map+bx], ax
            jmp .next
        .set_player2:
            bts [map+bx], ax
        .next:
            bts [map_enabled+bx], ax
            inc ch
            jmp .loop

    .toggle_player:
        xor ax, ax
        ret

    .end:
        mov ax, 1
        ret

wait_key:
    xor ax, ax
    int 0x16
    push ax
    call putchar
    ret

times 510-($-$$) db 0
db 0x55, 0xaa
