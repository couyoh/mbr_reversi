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
    lea si, [map_enabled]
    call ._rotate90
    lea si, [map]
    call ._rotate90
    xchg cx, bx
    abs bx, MAX_X-1
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

get_askew:
    cmp bx, MAX_Y
    jge .end
    cmp cx, MAX_Y
    jge .end
    bt [si+bx], cx
    jnc .finally
    bts di, cx
    .finally:
        inc bx
        inc cx
        jmp get_askew
    .end:
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
        jz .loop
        jl .set_zero_bx
        cmp cx, 0
        jz .loop
        jl .set_zero_cx
        jmp .find_start
    .set_zero_bx:
        xor bx, bx
        jmp .loop
    .set_zero_cx:
        xor cx, cx
    .loop:
        call [bp + 2]
    .end:
        mov [bp - 2], di
        popa
        mov ax, [bp - 2]
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

    ; If input coord is not empty, do nothing.
    bt [si], cx
    jc .end

    call change_piece
    mov dx, ax
    call rotate90 ; 90
    lea si, [map_enabled+bx]
    lea di, [map+bx]
    call change_piece
    add dx, ax

    call rotate90 ; 180
    call rotate90 ; 240
    call rotate90 ; 360

    pusha
    lea si, [map]
    push get_askew
    call askew
    push ax
    lea si, [map_enabled]
    push get_askew
    call askew
    mov si, ax
    pop di
    ; call count_piece
    popa

    cmp dx, 2 ; -> 3
    jz .end
    .toggle_player:
        xor byte [player], 1 ; toggle player
    .end:
        ret

change_piece:
    call count_piece

    ; If no same piece, do nothing.
    cmp ah, al
    jz .do_nothing

    mov cx, ax
    .loop:
        cmp ch, cl
        movzx ax, ch
        jg .changed
        cmp byte [player], 0
        jnz .set_player2
        .set_player1:
            btr [di], ax
            jmp .next
        .set_player2:
            bts [di], ax
        .next:
            bts [si], ax
            inc ch
            jmp .loop

    .changed:
        ; This subroutine would be called multiple times.
        ; If toggling player here, it may be overwritten when called again.
        xor ax, ax
        ret

    .do_nothing:
        mov ax, 1
        ret

count_piece:
    ; cx: x (0-7)
    push cx
    xor ax, ax
    mov dh, cl
    .dec_loop:
        dec cl
        cmp cl, 0
        jl .restore_ah
        bt [si], cx
        jnc .restore_ah
        call .aa
        jnz .dec_loop
        xchg bx, bx
        mov ah, cl
        jmp .mov_cl_dh
    .restore_ah:
        mov ah, dh
    .mov_cl_dh:
        mov cl, dh
    .inc_loop:
        inc cl
        cmp cl, MAX_X
        jge .restore_ah2
        bt [si], cx
        jnc .restore_ah2
        call .aa
        jnz .inc_loop
        mov al, cl
        jmp .end
    .restore_ah2:
        mov al, dh
    .end:
        pop cx
        ret
    .aa:
        bt [di], cx
        get_cf dl
        cmp dl, [player]
        ret

wait_key:
    xor ax, ax
    int 0x16
    push ax
    call putchar
    ret

times 510-($-$$) db 0
db 0x55, 0xaa
