; ===========================================================================
;  r_draw.asm -- растеризация столбцов и горизонтальных полос
; ===========================================================================

; ---------------------------------------------------------------------------
;  R_DrawColumn -- вертикальный столбец текстуры
;  Вход: dc_x, dc_yl, dc_yh, dc_iscale, dc_texturemid, dc_source,
;        dc_colormap, dc_texmask
; ---------------------------------------------------------------------------
R_DrawColumn:
    push    rbx
    push    rsi
    push    rdi
    mov     ecx, [dc_yh]
    sub     ecx, [dc_yl]
    js      .done
    inc     ecx
    mov     eax, [dc_yl]
    imul    eax, SCREENWIDTH
    add     eax, [dc_x]
    lea     rdi, [screens]
    add     rdi, rax
    mov     eax, [dc_yl]
    sub     eax, [centery]
    imul    eax, [dc_iscale]
    add     eax, [dc_texturemid]
    mov     edx, eax                    ; frac
    mov     rsi, [dc_source]
    mov     rbx, [dc_colormap]
    mov     r9d, [dc_texmask]
    mov     r10d, [dc_iscale]
.loop:
    mov     eax, edx
    sar     eax, 16
    and     eax, r9d
    movzx   eax, byte [rsi + rax]
    mov     al, [rbx + rax]
    mov     [rdi], al
    add     rdi, SCREENWIDTH
    add     edx, r10d
    dec     ecx
    jnz     .loop
.done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_DrawFuzzColumn -- "призрачный" столбец (частичная невидимость)
; ---------------------------------------------------------------------------
R_DrawFuzzColumn:
    push    rbx
    push    rsi
    push    rdi
    mov     eax, [dc_yl]
    test    eax, eax
    jnz     .yl_ok
    mov     dword [dc_yl], 1
.yl_ok:
    mov     eax, [dc_yh]
    cmp     eax, SCREENHEIGHT-2
    jle     .yh_ok
    mov     dword [dc_yh], SCREENHEIGHT-2
.yh_ok:
    mov     ecx, [dc_yh]
    sub     ecx, [dc_yl]
    js      .done
    inc     ecx
    mov     eax, [dc_yl]
    imul    eax, SCREENWIDTH
    add     eax, [dc_x]
    lea     rdi, [screens]
    add     rdi, rax
    mov     ebx, [fuzzpos]
    lea     rsi, [colormaps + 6*256]    ; тёмная карта
.loop:
    movzx   eax, byte [fuzzoffset + rbx]
    sub     eax, 1                      ; 0 -> -1, 1 -> 0
    imul    eax, SCREENWIDTH
    movzx   eax, byte [rdi + rax]
    mov     al, [rsi + rax]
    mov     [rdi], al
    inc     ebx
    cmp     ebx, FUZZTABLE
    jb      .nowrap
    xor     ebx, ebx
.nowrap:
    add     rdi, SCREENWIDTH
    dec     ecx
    jnz     .loop
    mov     [fuzzpos], ebx
.done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_DrawSpan -- горизонтальная полоса пола/потолка (флэт 64x64)
;  Вход: ds_x1, ds_x2, ds_y, ds_xfrac, ds_yfrac, ds_xstep, ds_ystep,
;        ds_source, ds_colormap
; ---------------------------------------------------------------------------
R_DrawSpan:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    mov     ecx, [ds_x2]
    sub     ecx, [ds_x1]
    js      .done
    inc     ecx
    mov     eax, [ds_y]
    imul    eax, SCREENWIDTH
    add     eax, [ds_x1]
    lea     rdi, [screens]
    add     rdi, rax
    mov     rsi, [ds_source]
    mov     rbx, [ds_colormap]
    mov     r8d, [ds_xfrac]
    mov     r9d, [ds_yfrac]
    mov     r10d, [ds_xstep]
    mov     r11d, [ds_ystep]
.loop:
    mov     eax, r9d
    sar     eax, 10
    and     eax, 0x0fc0
    mov     r12d, r8d
    sar     r12d, 16
    and     r12d, 63
    or      eax, r12d
    movzx   eax, byte [rsi + rax]
    mov     al, [rbx + rax]
    mov     [rdi], al
    inc     rdi
    add     r8d, r10d
    add     r9d, r11d
    dec     ecx
    jnz     .loop
.done:
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  V_Clear(cl = цвет) -- залить весь экран
; ---------------------------------------------------------------------------
V_Clear:
    push    rdi
    mov     al, cl
    mov     ah, al
    mov     dx, ax
    shl     eax, 16
    mov     ax, dx
    lea     rdi, [screens]
    mov     ecx, SCREENWIDTH*SCREENHEIGHT/4
.l: mov     [rdi], eax
    add     rdi, 4
    dec     ecx
    jnz     .l
    pop     rdi
    ret
