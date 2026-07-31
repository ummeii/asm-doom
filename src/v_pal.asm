; ===========================================================================
;  v_pal.asm -- 256-цветная палитра в стиле DOOM и COLORMAP (34 карты)
;
;  Палитра построена из линейных градиентов ("рамп"), как PLAYPAL в DOOM:
;  каждый диапазон идёт от яркого к тёмному, поэтому затемнение сводится
;  к сдвигу по рампе. COLORMAP строится поиском ближайшего цвета.
; ===========================================================================

%define PAL_BLACK   0
%define PAL_GRAY    1                   ; 1..31
%define PAL_BROWN   32                  ; 32..63
%define PAL_RED     64                  ; 64..95
%define PAL_GREEN   96                  ; 96..127
%define PAL_BLUE    128                 ; 128..159
%define PAL_YELLOW  160                 ; 160..175
%define PAL_ORANGE  176                 ; 176..191
%define PAL_FLESH   192                 ; 192..207
%define PAL_TEAL    208                 ; 208..223
%define PAL_PURPLE  224                 ; 224..239
%define PAL_TAN     240                 ; 240..255

%define PAL_NUMRAMPS 11
%define NUMCOLORMAPS 32
%define INVERSECOLORMAP 32

; ---------------------------------------------------------------------------
;  V_InitPalette
; ---------------------------------------------------------------------------
V_InitPalette:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15

    ; --- рампы ---
    xor     r12d, r12d                  ; индекс рампы
.ramploop:
    lea     rsi, [pal_ramps]
    imul    eax, r12d, 8
    add     rsi, rax
    movzx   r13d, byte [rsi + 0]        ; start
    movzx   r14d, byte [rsi + 1]        ; count
    test    r14d, r14d
    jz      .rampdone

    xor     ebx, ebx                    ; i
.entry:
    ; c = c0 + (c1-c0)*i/(count-1)
    xor     edi, edi                    ; компонента
.comp:
    movzx   eax, byte [rsi + 2 + rdi]   ; c0
    movzx   ecx, byte [rsi + 5 + rdi]   ; c1
    sub     ecx, eax                    ; delta
    imul    ecx, ebx
    mov     r8d, r14d
    dec     r8d
    jnz     .div
    xor     ecx, ecx
    jmp     .nodiv
.div:
    mov     r9d, eax
    mov     eax, ecx
    cdq
    idiv    r8d
    mov     ecx, eax
    mov     eax, r9d
.nodiv:
    add     eax, ecx
    ; запись
    mov     r10d, r13d
    add     r10d, ebx
    imul    r10d, r10d, 3
    add     r10d, edi
    mov     [g_palette + r10], al
    inc     edi
    cmp     edi, 3
    jb      .comp
    inc     ebx
    cmp     ebx, r14d
    jb      .entry

    inc     r12d
    cmp     r12d, PAL_NUMRAMPS
    jb      .ramploop
.rampdone:
    ; чёрный
    mov     byte [g_palette + 0], 0
    mov     byte [g_palette + 1], 0
    mov     byte [g_palette + 2], 0

    ; --- COLORMAP: 32 уровня освещения ---
    xor     r12d, r12d                  ; k
.maploop:
    xor     ebx, ebx                    ; цвет
.colloop:
    lea     rsi, [g_palette]
    lea     rsi, [rsi + rbx*2]
    add     rsi, rbx                    ; g_palette + c*3
    ; scale = (31-k)/31
    mov     r14d, 31
    sub     r14d, r12d                  ; числитель
    movzx   ecx, byte [rsi + 0]
    imul    ecx, r14d
    mov     eax, ecx
    xor     edx, edx
    mov     ecx, 31
    div     ecx
    mov     r8d, eax                    ; R
    movzx   ecx, byte [rsi + 1]
    imul    ecx, r14d
    mov     eax, ecx
    xor     edx, edx
    mov     ecx, 31
    div     ecx
    mov     r9d, eax                    ; G
    movzx   ecx, byte [rsi + 2]
    imul    ecx, r14d
    mov     eax, ecx
    xor     edx, edx
    mov     ecx, 31
    div     ecx
    mov     r10d, eax                   ; B
    mov     ecx, r8d
    mov     edx, r9d
    mov     r8d, r10d
    call    V_BestColor
    mov     r10d, r12d
    shl     r10d, 8
    add     r10d, ebx
    mov     [colormaps + r10], al
    inc     ebx
    cmp     ebx, 256
    jb      .colloop
    inc     r12d
    cmp     r12d, NUMCOLORMAPS
    jb      .maploop

    ; --- карта неуязвимости: инверсия яркости ---
    xor     ebx, ebx
.invloop:
    lea     rsi, [g_palette]
    lea     rsi, [rsi + rbx*2]
    add     rsi, rbx
    movzx   eax, byte [rsi + 0]
    imul    eax, 77
    movzx   ecx, byte [rsi + 1]
    imul    ecx, 151
    add     eax, ecx
    movzx   ecx, byte [rsi + 2]
    imul    ecx, 28
    add     eax, ecx
    shr     eax, 8                      ; яркость
    mov     ecx, 255
    sub     ecx, eax                    ; инверсия
    mov     edx, ecx
    mov     r8d, ecx
    call    V_BestColor
    mov     r10d, INVERSECOLORMAP
    shl     r10d, 8
    add     r10d, ebx
    mov     [colormaps + r10], al
    inc     ebx
    cmp     ebx, 256
    jb      .invloop

    ; --- полностью чёрная карта ---
    xor     ebx, ebx
.blkloop:
    mov     byte [colormaps + 33*256 + rbx], 0
    inc     ebx
    cmp     ebx, 256
    jb      .blkloop

    call    I_SetPalette

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  V_BestColor(ecx=r, edx=g, r8d=b) -> eax = ближайший индекс палитры
; ---------------------------------------------------------------------------
V_BestColor:
    push    rbx
    push    rsi
    push    rdi
    mov     r9d, 0x7fffffff             ; лучшая дистанция
    xor     r10d, r10d                  ; лучший индекс
    xor     ebx, ebx
.l:
    lea     rsi, [g_palette]
    lea     rsi, [rsi + rbx*2]
    add     rsi, rbx
    movzx   eax, byte [rsi + 0]
    sub     eax, ecx
    imul    eax, eax
    mov     edi, eax
    movzx   eax, byte [rsi + 1]
    sub     eax, edx
    imul    eax, eax
    add     edi, eax
    movzx   eax, byte [rsi + 2]
    sub     eax, r8d
    imul    eax, eax
    add     edi, eax
    cmp     edi, r9d
    jae     .next
    mov     r9d, edi
    mov     r10d, ebx
.next:
    inc     ebx
    cmp     ebx, 256
    jb      .l
    mov     eax, r10d
    pop     rdi
    pop     rsi
    pop     rbx
    ret
