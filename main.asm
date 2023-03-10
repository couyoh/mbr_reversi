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
            db 0b00011110, ; 5
            db 0b00010000, ; 6
            db 0b00100000, ; 7
            db 0b00000000  ; 8

       ; hgfedcba
map db 0b00000000, ; 1
    db 0b00000000, ; 2
    db 0b00000000, ; 3
    db 0b00010000, ; 4
    db 0b00011110, ; 5
    db 0b00000000, ; 6
    db 0b00000000, ; 7
    db 0b00000000  ; 8


init:
    mov ax, 3
    int 0x10
    .loop:
        .draw:
            mov ax, 'a'
            xor bx, bx
            .title:
                cmp ax, 'a'+MAX_X
                jz .x
                call putchar
                inc ax
                jmp .title
            .x:
                call print_0d0a
                cmp bx, MAX_X
                jz .main
                xor cx, cx
                .y:
                    cmp cl, MAX_Y
                    jz .end_y
                    ; check whether the stone is placed
                    bt [map_enabled+bx], cx
                    jnc .print_empty

                    ; check whose stone
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
                    mov ax, bx
                    add al, '1'
                    call putchar
                    inc bx
                    jmp .x
    .main:
        call main
        jmp .loop

rotate90:
    lea si, [map_enabled]
    call ._rotate90
    add si, 8
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
    push bx
    push cx
    call .find_start
    lea si, [map_enabled]
    xor ax, ax
    .map_bitcheck:
        cmp bx, MAX_Y
        jge .end
        cmp cx, MAX_X
        jge .end
        bt [si+bx+MAX_Y], cx
        jnc .map_enabled_bitcheck
        bts ax, cx ; al = map
        .map_enabled_bitcheck:
            bt [si+bx], cx
            jnc .next
            xchg al, ah
            bts ax, cx ; ah = map_enabled
            xchg ah, al
        .next:
            inc bx
            call di
            js .end ; jump if .dec's retval < 0
            jmp .map_bitcheck
        .inc:
            inc cx
            ret
        .dec:
            dec cx
            ret
    .end:
        movzx si, ah
        movzx di, al
        pop cx
        pop bx
        ret
    .find_start:
        sub bx, cx
        jc .set_cx
        xor cx, cx
        ret
        .set_cx:
            add bx, MAX_X-1
            mov cx, bx
            xor bx, bx
            ret

print_0d0a:
    mov al, NEWLINE_0D
    call putchar
    mov al, NEWLINE_0A
    call putchar
    ret


main:
    call wait_key ; x must be between a and h
    movzx cx, al
    sub cl, 'a'
    call wait_key ; y must be between 1 and 8
    movzx bx, al
    sub bl, '1'
    call print_0d0a

    xor dx, dx
    call .find_and_change

    call rotate90
    call .find_and_change

    ; rotate90 overwrites map_enabled and map.
    ; That's why it calls rotate90 multiple times.
    call rotate90 ; 180
    call rotate90 ; 240
    call rotate90 ; 360

    ; inverse
    mov di, askew.inc
    call askew
    xor di, di
    push .inc_sidi
    call find_and_change

    ; direct
    push cx
    abs cx, 7
    mov di, askew.dec
    call askew
    pop cx
    push .inc_sidi_decdi
    call find_and_change

    ; Toggle player if the stone has enabled.
    mov si, [map_enabled+bx]
    bt si, cx
    jnc .end
    xor byte [player], 1

    .end:
        ret

    .inc_sidi_decdi:
        mov di, askew.dec
    .inc_sidi:
        push bx
        push cx
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
    .find_and_change:
        call .make_sidi
        mov si, [si] ; map_enabled+bx
        mov di, [di] ; map_enabled+bx+8
        push .make_sidi
        call find_and_change
        ret

; bx: [in] myself y
; cx: [in] myself x
; dh: [var]
; dl: [var]
find_and_change:
    mov bp, sp
    .count_stone:
        xor dl, dl
        call find
        mov dh, al

        inc dl
        call find

        cmp al, dh
        je .ret


    .loop:
        call [bp + 2] ; inc_sidi
        cmp al, dh
        jg .ret
        cmp byte [player], 0
        jnz .set_player2
        .set_player1:
            btr [di], ax
            jmp .next
        .set_player2:
            bts [di], ax
        .next:
            bts [si], ax
        inc al
        jmp .loop
    .ret:
        ret 2

; dl: [in] Increment if 0, otherwise Decrement
; cx: [in] myself x
; si: [in] map_enabled
; di: [in] map
; ax: [out] return
find:
    mov ax, cx
    .count_loop:
        test dl, dl
        jz .inc
        .dec:
            dec ax
            jmp .check_enabled
        .inc:
            inc ax
        .check_enabled:
            cmp ax, 0
            jl .restore
            cmp ax, MAX_X
            jg .restore
            bt si, ax
            jnc .restore
        .check:
            bt di, ax
            push dx
            get_cf dl
            cmp dl, byte [player]
            pop dx
            jnz .count_loop

            test dl, dl
            jz ._dec
            inc ax
            jmp .ret
            ._dec:
                dec ax
            .ret:
                ret
    .restore:
        mov ax, cx
        ret

wait_key:
    xor ax, ax
    int 0x16
    call putchar
    ret

putchar:
    pusha
    mov ah, 0xe
    xor bx, bx
    int 0x10
    popa
    ret

times 510-($-$$) db 0
db 0x55, 0xaa
