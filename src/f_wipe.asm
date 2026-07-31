; ===========================================================================
;  f_wipe.asm -- «расплавление» экрана при смене уровня
;
;  Порт wipe_doMelt из f_wipe.c: экран разбит на столбцы, каждый начинает
;  съезжать со своей задержкой и ускоряется, пока не закроет старый кадр.
; ===========================================================================

%define WIPE_OFF    0                   ; ничего не происходит
%define WIPE_SNAP   1                   ; следующий кадр -- конечный
%define WIPE_MELT   2                   ; идёт расплавление

; ---------------------------------------------------------------------------
;  V_StartWipe -- запомнить текущий кадр как начальный
; ---------------------------------------------------------------------------
V_StartWipe:
    push    rbx
    push    rsi
    push    rdi
    ; текущее содержимое экрана -- то, что будет "стекать"
    lea     rsi, [screens]
    lea     rdi, [wipe_start]
    mov     ecx, SCREENWIDTH*SCREENHEIGHT
    rep     movsb
    mov     dword [wipe_state], WIPE_SNAP
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  V_WipeInitCols -- начальные смещения столбцов (wipe_initMelt)
; ---------------------------------------------------------------------------
V_WipeInitCols:
    push    rbx
    push    rsi
    ; y[0] = -(M_Random()%16)
    call    P_Random
    and     eax, 15
    neg     eax
    mov     [wipe_y], eax
    mov     esi, eax
    mov     ebx, 1
.l:
    call    P_Random
    xor     edx, edx
    mov     ecx, 3
    div     ecx
    dec     edx                         ; -1, 0 или 1
    add     esi, edx
    cmp     esi, 0
    jle     .notpos
    xor     esi, esi
.notpos:
    cmp     esi, -15
    jge     .ok
    mov     esi, -15
.ok:
    mov     [wipe_y + rbx*4], esi
    inc     ebx
    cmp     ebx, SCREENWIDTH
    jb      .l
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  V_DoWipe -> eax = 1, если расплавление закончилось
;
;  За тик каждый столбец сдвигается вниз: сперва по одному пикселю с
;  разгоном, после 16 пикселей -- сразу по восемь, как в оригинале.
; ---------------------------------------------------------------------------
V_DoWipe:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    mov     r14d, 1                     ; готово?
    xor     ebx, ebx                    ; столбец
.col:
    mov     r12d, [wipe_y + rbx*4]
    cmp     r12d, 0
    jge     .started
    ; ещё не тронулся
    inc     dword [wipe_y + rbx*4]
    xor     r14d, r14d
    jmp     .draw
.started:
    cmp     r12d, SCREENHEIGHT
    jae     .draw                       ; столбец уже полностью съехал
    xor     r14d, r14d
    ; шаг: разгон до 8 пикселей за тик
    mov     r13d, 8
    cmp     r12d, 16
    jge     .haved
    lea     r13d, [r12d + 1]
.haved:
    mov     eax, r12d
    add     eax, r13d
    cmp     eax, SCREENHEIGHT
    jle     .dok
    mov     r13d, SCREENHEIGHT
    sub     r13d, r12d
.dok:
    add     [wipe_y + rbx*4], r13d
.draw:
    ; --- собрать столбец: сверху новый кадр, ниже сползающий старый ---
    mov     r12d, [wipe_y + rbx*4]
    cmp     r12d, 0
    jge     .clamp0
    xor     r12d, r12d
.clamp0:
    cmp     r12d, SCREENHEIGHT
    jle     .clamph
    mov     r12d, SCREENHEIGHT
.clamph:
    ; верхняя часть -- конечный кадр
    xor     esi, esi                    ; строка
    mov     edi, ebx
.topl:
    cmp     esi, r12d
    jae     .bottom
    mov     al, [wipe_end + rdi]
    mov     [screens + rdi], al
    add     edi, SCREENWIDTH
    inc     esi
    jmp     .topl
.bottom:
    ; нижняя часть -- начальный кадр, сдвинутый вниз на y
    mov     esi, r12d                   ; строка экрана
    mov     edi, ebx
    imul    eax, r12d, SCREENWIDTH
    add     edi, eax                    ; смещение в screens
    mov     r13d, ebx                   ; смещение в wipe_start
.botl:
    cmp     esi, SCREENHEIGHT
    jae     .colnext
    mov     al, [wipe_start + r13]
    mov     [screens + rdi], al
    add     edi, SCREENWIDTH
    add     r13d, SCREENWIDTH
    inc     esi
    jmp     .botl
.colnext:
    inc     ebx
    cmp     ebx, SCREENWIDTH
    jb      .col
    mov     eax, r14d
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  V_WipeFrame -- вызывается из D_Display после отрисовки кадра
; ---------------------------------------------------------------------------
V_WipeFrame:
    push    rbx
    push    rsi
    push    rdi
    cmp     dword [wipe_state], WIPE_SNAP
    jne     .melt
    ; только что нарисован первый кадр нового уровня -- он и есть конечный
    lea     rsi, [screens]
    lea     rdi, [wipe_end]
    mov     ecx, SCREENWIDTH*SCREENHEIGHT
    rep     movsb
    call    V_WipeInitCols
    mov     dword [wipe_state], WIPE_MELT
.melt:
    cmp     dword [wipe_state], WIPE_MELT
    jne     .done
    call    V_DoWipe
    test    eax, eax
    jz      .done
    mov     dword [wipe_state], WIPE_OFF
.done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret
