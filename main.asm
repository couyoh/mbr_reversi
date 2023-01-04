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

reverse_bit:
    mov bp, sp
    push bx
    push cx
    xor ax, ax
    xor cx, cx
    .loop:
        cmp cx, MAX_X
        jz .end
        bt [bp + 2], cx
        jnc .finally
        mov bx, MAX_X-1
        sub bx, cx
        bts ax, bx
    .finally:
        inc cx
        jmp .loop
    .end:
        pop cx
        pop bx
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
    ; sub sp, 2
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
        mov [bp + 2], di
        ; add sp, 2
        popa
        mov ax, [bp + 2]
        ret

check_piece:
    mov bp, sp
    push cx
    mov cx, [bp + 6] ; base
    xor ax, ax
    ; Maybe I can use BSF/BSR instruction.
    .loop:
        inc cl
        cmp cl, MAX_X
        jge .clear
        bt [bp + 2], cx ; map_enabled
        jnc .clear
        bt [bp + 4], cx ; map
        get_cf ah
        cmp ah, [player]
        jz .end
        inc al ; number of same pieces (+x direction)
        jmp .loop
    .clear:
        xor al, al
    .end:
        xor ah, ah
        pop cx
        ret 6

change_piece:
    ; To reduce code, it doesn't use calling convention.
    ; mov bp, sp
    ; push cx
    ; mov cx, [bp + 2]
    .loop:
        cmp ch, cl
        movzx ax, ch
        jg .end
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
    .end:
        ; pop cx
        ; ret 2
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
    ; .title:
    ;     cmp dx, MAX_X
    ;     jz .x
    ;     mov ax, dx
    ;     add ax, 'a'
    ;     push ax
    ;     call putchar
    ;     inc dx
    ;     jmp .title
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
    call detect_loop
    call to_xy ; 90
    call detect_loop
    call to_xy ; 180
    call to_xy ; 240
    call to_xy ; 360
    ; bx, cx has already been defined at to_xy subroutine.
    lea si, [map]
    call askew
    push word [map + bx]
    push word [map_enabled + bx]
    push bx
    mov [map + bx], ax
    lea si, [map_enabled]
    call askew
    mov [map_enabled + bx], ax
    call detect_loop
    pop bx
    pop word [map_enabled + bx]
    pop word [map + bx]
    ret

to_xy:
    lea si, [map_enabled]
    call x_to_y
    lea si, [map]
    call x_to_y
    push cx
    mov cx, bx
    pop bx
    sub bx, MAX_X-1
    neg bx
    movzx bx, bl
    ret

detect_loop:
    ; If input coord is not empty, do nothing.
    bt [map_enabled+bx], cx
    jc .end

    call count_piece
    mov cx, dx

    ; If no same piece, do nothing.
    cmp ch, cl
    jz .end

    ; push cx
    call change_piece

    ; toggle player
    mov dl, [player]
    xor dl, 1
    mov [player], dl

    .end:
        ret

wait_key:
    xor ax, ax
    int 0x16
    push ax
    call putchar
    ret

count_piece:
    push cx
    push word [map + bx]
    push word [map_enabled + bx]
    call check_piece
    mov dl, al

    mov ax, cx
    sub ax, MAX_X
    not ax
    push ax
    push word [map + bx]
    call reverse_bit
    push ax
    push word [map_enabled + bx]
    call reverse_bit
    push ax
    call check_piece
    mov dh, al

    add dl, cl
    sub dh, cl
    neg dh
    ret


times 510-($-$$) db 0
db 0x55, 0xaa
