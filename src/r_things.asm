; ===========================================================================
;  r_things.asm -- процедурная генерация спрайтов и их отрисовка
; ===========================================================================

%define MAXVISSPRITES 128
%define MAXSPRFRAMES  16
%define MINZ          (FRACUNIT*4)
%define FF_FRAMEMASK  0x7fff

%define VS_X1       0
%define VS_X2       4
%define VS_SCALE    8
%define VS_XISCALE  12
%define VS_TEXMID   16
%define VS_STARTFRAC 20
%define VS_GX       24
%define VS_GY       28
%define VS_GZ       32
%define VS_GZT      36
%define VS_FLAGS    40
%define VS_PATCH    48      ; dq
%define VS_COLORMAP 56      ; dq
%define VS_SIZE     64

; патч: width(0), height(4), leftoffset(8), topoffset(12), columnofs[width](16)
%define PA_WIDTH    0
%define PA_HEIGHT   4
%define PA_LEFT     8
%define PA_TOP      12
%define PA_COLOFS   16

; ===========================================================================
;  Растеризация во временный буфер
; ===========================================================================
; SPR_Begin(ecx = w, edx = h)
SPR_Begin:
    push    rdi
    mov     [bake_w], ecx
    mov     [bake_h], edx
    imul    ecx, edx
    lea     rdi, [bakebuf]
    xor     eax, eax
.l: mov     [rdi], al
    inc     rdi
    dec     ecx
    jnz     .l
    pop     rdi
    ret

; SPR_Pixel(ecx = x, edx = y, r8d = цвет)
SPR_Pixel:
    cmp     ecx, 0
    jl      .out
    cmp     ecx, [bake_w]
    jge     .out
    cmp     edx, 0
    jl      .out
    cmp     edx, [bake_h]
    jge     .out
    mov     eax, edx
    imul    eax, [bake_w]
    add     eax, ecx
    mov     [bakebuf + rax], r8b
.out:
    ret

; SPR_Ellipse(ecx=cx, edx=cy, r8d=rx, r9d=ry, [sp_color], [sp_edge])
SPR_Ellipse:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12d, ecx
    mov     r13d, edx
    mov     r14d, r8d
    mov     r15d, r9d
    test    r14d, r14d
    jle     .done
    test    r15d, r15d
    jle     .done
    mov     esi, r15d
    neg     esi                         ; dy
.yl:
    cmp     esi, r15d
    jg      .done
    mov     edi, r14d
    neg     edi                         ; dx
.xl:
    cmp     edi, r14d
    jg      .ynext
    ; (dx/rx)^2 + (dy/ry)^2 <= 1  ->  dx*dx*ry*ry + dy*dy*rx*rx <= rx*rx*ry*ry
    mov     eax, edi
    imul    eax, edi
    mov     ecx, r15d
    imul    ecx, r15d
    imul    eax, ecx
    mov     ebx, eax
    mov     eax, esi
    imul    eax, esi
    mov     ecx, r14d
    imul    ecx, r14d
    imul    eax, ecx
    add     ebx, eax
    mov     eax, r14d
    imul    eax, r14d
    mov     ecx, r15d
    imul    ecx, r15d
    imul    eax, ecx
    cmp     ebx, eax
    jg      .xnext
    ; цвет: край темнее
    mov     r8d, [sp_color]
    mov     ecx, eax
    sar     ecx, 2
    imul    ecx, 3
    cmp     ebx, ecx
    jl      .fill
    mov     r8d, [sp_edge]
.fill:
    lea     ecx, [r12d + edi]
    lea     edx, [r13d + esi]
    call    SPR_Pixel
.xnext:
    inc     edi
    jmp     .xl
.ynext:
    inc     esi
    jmp     .yl
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; SPR_Rect(ecx=x0, edx=y0, r8d=x1, r9d=y1) цвет в sp_color
SPR_Rect:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    mov     r12d, ecx                   ; x0
    mov     r13d, r8d                   ; x1
    mov     r14d, r9d                   ; y1
    mov     esi, edx                    ; y
.yl:
    cmp     esi, r14d
    jg      .done
    mov     edi, r12d
.xl:
    cmp     edi, r13d
    jg      .ynext
    mov     ecx, edi
    mov     edx, esi
    mov     r8d, [sp_color]
    call    SPR_Pixel
    inc     edi
    jmp     .xl
.ynext:
    inc     esi
    jmp     .yl
.done:
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  SPR_Bake(ecx = leftoffset, edx = topoffset) -> rax = патч
; ---------------------------------------------------------------------------
SPR_Bake:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r14d, ecx
    mov     r15d, edx
    ; оценка размера: заголовок + столбцы
    mov     ecx, [bake_w]
    imul    ecx, [bake_h]
    add     ecx, [bake_w]
    imul    ecx, 3
    add     ecx, 256
    call    Z_Malloc
    mov     rbx, rax
    mov     eax, [bake_w]
    mov     [rbx + PA_WIDTH], eax
    mov     eax, [bake_h]
    mov     [rbx + PA_HEIGHT], eax
    mov     [rbx + PA_LEFT], r14d
    mov     [rbx + PA_TOP], r15d
    ; данные столбцов после таблицы смещений
    mov     eax, [bake_w]
    shl     eax, 2
    add     eax, PA_COLOFS
    mov     r12d, eax                   ; текущее смещение записи
    xor     esi, esi                    ; x
.colloop:
    mov     eax, esi
    mov     [rbx + PA_COLOFS + rsi*4], r12d
    ; ищем непрозрачные участки
    xor     edi, edi                    ; y
.postscan:
    cmp     edi, [bake_h]
    jae     .colend
    mov     eax, edi
    imul    eax, [bake_w]
    add     eax, esi
    cmp     byte [bakebuf + rax], 0
    je      .nextpix
    ; начало поста
    mov     r13d, edi                   ; topdelta
    mov     eax, r13d
    mov     [rbx + r12], al             ; topdelta
    inc     r12d
    mov     r14d, r12d                  ; здесь будет длина
    inc     r12d
    inc     r12d                        ; пропуск байта-заполнителя
    xor     r15d, r15d                  ; длина
.postpix:
    cmp     edi, [bake_h]
    jae     .postend
    cmp     r15d, 254
    jae     .postend
    mov     eax, edi
    imul    eax, [bake_w]
    add     eax, esi
    mov     al, [bakebuf + rax]
    test    al, al
    jz      .postend
    mov     [rbx + r12], al
    inc     r12d
    inc     r15d
    inc     edi
    jmp     .postpix
.postend:
    mov     eax, r15d
    mov     [rbx + r14], al             ; длина
    inc     r12d                        ; хвостовой байт
    jmp     .postscan
.nextpix:
    inc     edi
    jmp     .postscan
.colend:
    mov     byte [rbx + r12], 0xff      ; конец столбца
    inc     r12d
    inc     esi
    cmp     esi, [bake_w]
    jb      .colloop
    mov     rax, rbx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_SetSprite(ecx=спрайт, edx=кадр, r8d=ракурс, r9=патч)
; ---------------------------------------------------------------------------
R_SetSprite:
    mov     eax, ecx
    imul    eax, MAXSPRFRAMES*8
    mov     r10d, edx
    imul    r10d, 8
    add     eax, r10d
    add     eax, r8d
    lea     r10, [spriteframes]
    mov     [r10 + rax*8], r9
    ret

; R_GetSprite(ecx=спрайт, edx=кадр, r8d=ракурс) -> rax
R_GetSprite:
    mov     eax, ecx
    imul    eax, MAXSPRFRAMES*8
    mov     r10d, edx
    imul    r10d, 8
    add     eax, r10d
    add     eax, r8d
    lea     r10, [spriteframes]
    mov     rax, [r10 + rax*8]
    ret

; ===========================================================================
;  Генерация спрайтов
; ===========================================================================
R_InitSprites:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15

    ; --- существа ---
    xor     r12d, r12d                  ; индекс описания
.crloop:
    imul    eax, r12d, 8
    lea     rsi, [creaturedefs]
    add     rsi, rax
    movzx   r13d, byte [rsi + 0]        ; номер спрайта
    cmp     r13d, 255
    je      .crdone
    movzx   r14d, byte [rsi + 1]        ; базовый цвет тела
    movzx   r15d, byte [rsi + 2]        ; цвет головы
    movzx   ebx, byte [rsi + 3]         ; высота
    movzx   edi, byte [rsi + 4]         ; ширина
    movzx   eax, byte [rsi + 5]         ; стиль
    mov     [cr_style], eax
    mov     [cr_body], r14d
    mov     [cr_head], r15d
    mov     [cr_h], ebx
    mov     [cr_w], edi
    mov     [cr_spr], r13d
    call    R_MakeCreature
    inc     r12d
    jmp     .crloop
.crdone:

    ; --- предметы ---
    xor     r12d, r12d
.itloop:
    imul    eax, r12d, 8
    lea     rsi, [itemdefs]
    add     rsi, rax
    movzx   r13d, byte [rsi + 0]
    cmp     r13d, 255
    je      .itdone
    movzx   r14d, byte [rsi + 1]        ; цвет
    movzx   r15d, byte [rsi + 2]        ; форма
    movzx   ebx, byte [rsi + 3]         ; размер
    movzx   edi, byte [rsi + 4]         ; кадров
    mov     [cr_spr], r13d
    mov     [cr_body], r14d
    mov     [cr_style], r15d
    mov     [cr_h], ebx
    mov     [cr_w], edi
    call    R_MakeItem
    inc     r12d
    jmp     .itloop
.itdone:

    call    R_MakeWeapons
    call    R_MakeEffects
    call    R_ApplyArt                  ; рисованные спрайты поверх процедурных


    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_MakeCreature -- 13 кадров x 8 ракурсов
; ---------------------------------------------------------------------------
R_MakeCreature:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    xor     r12d, r12d                  ; кадр
.frameloop:
    xor     r13d, r13d                  ; ракурс
.rotloop:
    ; размер холста
    mov     ecx, [cr_w]
    add     ecx, 8
    mov     edx, [cr_h]
    add     edx, 4
    call    SPR_Begin
    mov     ecx, r12d
    mov     edx, r13d
    call    R_DrawCreatureFrame
    mov     ecx, [bake_w]
    shr     ecx, 1
    mov     edx, [bake_h]
    call    SPR_Bake
    mov     r9, rax
    mov     ecx, [cr_spr]
    mov     edx, r12d
    mov     r8d, r13d
    call    R_SetSprite
    inc     r13d
    cmp     r13d, 8
    jb      .rotloop
    inc     r12d
    cmp     r12d, 13
    jb      .frameloop
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; R_DrawCreatureFrame(ecx = кадр, edx = ракурс)
;   Пропорции человекоподобного: ноги 0..30% высоты, торс 28..72%,
;   плечи на 68%, голова сверху. Ширина зависит от ракурса: анфас и со спины
;   тело широкое, в профиль -- вдвое уже.
R_DrawCreatureFrame:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12d, ecx                   ; кадр
    mov     r13d, edx                   ; ракурс
    mov     r14d, [bake_w]
    shr     r14d, 1                     ; центр X
    mov     r15d, [bake_h]              ; низ (ноги)

    ; --- ширина по ракурсу ---
    mov     eax, [cr_w]
    cmp     r13d, 0
    je      .wfull
    cmp     r13d, 4
    je      .wfull
    cmp     r13d, 2
    je      .whalf
    cmp     r13d, 6
    je      .whalf
    imul    eax, 6
    shr     eax, 3                      ; диагональ: 3/4
    jmp     .wdone
.whalf:
    shr     eax, 1                      ; профиль: 1/2
    jmp     .wdone
.wfull:
.wdone:
    cmp     eax, 8
    jge     .wok
    mov     eax, 8
.wok:
    mov     [cr_bw], eax                ; ширина тела в этом ракурсе

    cmp     r12d, 8
    jae     .dead
    cmp     dword [cr_style], 1
    je      .blob
    cmp     dword [cr_style], 2
    je      .float

; ============================ человекоподобный =============================
    ; фаза ног/рук
    mov     eax, r12d
    and     eax, 3
    mov     esi, [legphase + rax*4]

    ; --- ноги ---
    mov     eax, [cr_body]
    add     eax, 11
    mov     [sp_color], eax
    add     eax, 7
    mov     [sp_edge], eax
    mov     eax, [cr_h]
    imul    eax, 30
    mov     ecx, 100
    xor     edx, edx
    div     ecx
    mov     edi, eax                    ; длина ног
    mov     eax, [cr_bw]
    mov     ecx, 5
    xor     edx, edx
    div     ecx
    mov     ebx, eax                    ; полурасстояние между ногами
    mov     ecx, r14d
    sub     ecx, ebx
    add     ecx, esi
    mov     edx, r15d
    mov     eax, edi
    shr     eax, 1
    sub     edx, eax
    mov     r8d, [cr_bw]
    mov     r9d, 6
    xor     edx, edx
    push    rdx
    mov     eax, r8d
    xor     edx, edx
    div     r9d
    pop     rdx
    mov     r8d, eax                    ; полуширина ноги = bw/6
    mov     edx, r15d
    mov     eax, edi
    shr     eax, 1
    sub     edx, eax
    mov     r9d, edi
    shr     r9d, 1
    call    SPR_Ellipse
    mov     eax, [cr_bw]
    mov     ecx, 6
    xor     edx, edx
    div     ecx
    mov     r8d, eax
    mov     ecx, r14d
    add     ecx, ebx
    sub     ecx, esi
    mov     edx, r15d
    mov     eax, edi
    shr     eax, 1
    sub     edx, eax
    mov     r9d, edi
    shr     r9d, 1
    call    SPR_Ellipse

    ; --- торс ---
    mov     eax, [cr_body]
    add     eax, 4
    mov     [sp_color], eax
    add     eax, 9
    mov     [sp_edge], eax
    mov     eax, [cr_h]
    imul    eax, 24
    mov     ecx, 100
    xor     edx, edx
    div     ecx
    mov     ebx, eax                    ; полувысота торса
    mov     ecx, r14d
    mov     eax, [cr_h]
    imul    eax, 50
    mov     r9d, 100
    xor     edx, edx
    div     r9d
    mov     edx, r15d
    sub     edx, eax                    ; центр торса
    mov     r8d, [cr_bw]
    imul    r8d, 3
    shr     r8d, 3                      ; полуширина торса = 3/8 ширины
    mov     r9d, ebx
    call    SPR_Ellipse

    ; --- плечи ---
    mov     eax, [cr_h]
    imul    eax, 68
    mov     ecx, 100
    xor     edx, edx
    div     ecx
    mov     edx, r15d
    sub     edx, eax
    mov     ecx, r14d
    mov     r8d, [cr_bw]
    imul    r8d, 7
    shr     r8d, 4
    mov     r9d, [cr_h]
    imul    r9d, 7
    push    rcx
    push    rdx
    push    r8
    mov     eax, r9d
    mov     ecx, 100
    xor     edx, edx
    div     ecx
    mov     r9d, eax
    pop     r8
    pop     rdx
    pop     rcx
    test    r9d, r9d
    jnz     .shok
    mov     r9d, 1
.shok:
    call    SPR_Ellipse

    ; --- руки ---
    mov     eax, [cr_body]
    add     eax, 7
    mov     [sp_color], eax
    add     eax, 7
    mov     [sp_edge], eax
    mov     eax, [cr_bw]
    imul    eax, 7
    shr     eax, 4
    mov     ebx, eax                    ; вынос руки от центра
    mov     eax, [cr_h]
    imul    eax, 14
    mov     ecx, 100
    xor     edx, edx
    div     ecx
    mov     edi, eax                    ; полудлина руки
    mov     eax, [cr_h]
    imul    eax, 55
    mov     ecx, 100
    xor     edx, edx
    div     ecx
    mov     esi, r15d
    sub     esi, eax                    ; центр руки по Y
    ; в кадрах атаки руки выносятся вперёд и вверх
    cmp     r12d, 4
    jb      .armnorm
    cmp     r12d, 7
    jae     .armnorm
    mov     eax, [cr_h]
    imul    eax, 8
    mov     ecx, 100
    xor     edx, edx
    div     ecx
    sub     esi, eax
    shr     ebx, 1
.armnorm:
    mov     eax, [cr_bw]
    mov     ecx, 7
    xor     edx, edx
    div     ecx
    test    eax, eax
    jnz     .arw
    mov     eax, 1
.arw:
    mov     r8d, eax
    mov     ecx, r14d
    sub     ecx, ebx
    mov     edx, esi
    mov     r9d, edi
    call    SPR_Ellipse
    mov     eax, [cr_bw]
    mov     ecx, 7
    xor     edx, edx
    div     ecx
    test    eax, eax
    jnz     .arw2
    mov     eax, 1
.arw2:
    mov     r8d, eax
    mov     ecx, r14d
    add     ecx, ebx
    mov     edx, esi
    mov     r9d, edi
    call    SPR_Ellipse

    ; --- голова ---
    mov     eax, [cr_h]
    mov     ecx, 9
    xor     edx, edx
    div     ecx
    mov     ebx, eax                    ; радиус головы
    test    ebx, ebx
    jnz     .hr
    mov     ebx, 2
.hr:
    mov     eax, [cr_h]
    imul    eax, 80
    mov     ecx, 100
    xor     edx, edx
    div     ecx
    mov     esi, r15d
    sub     esi, eax                    ; центр головы
    mov     eax, [cr_head]
    add     eax, 3
    mov     [sp_color], eax
    add     eax, 8
    mov     [sp_edge], eax
    mov     ecx, r14d
    mov     edx, esi
    mov     r8d, ebx
    mov     r9d, ebx
    call    SPR_Ellipse
    ; глаза только анфас
    cmp     r13d, 0
    jne     .done
    mov     eax, ebx
    shr     eax, 1
    inc     eax
    mov     ecx, r14d
    sub     ecx, eax
    mov     edx, esi
    mov     r8d, PAL_RED + 1
    push    rax
    push    rsi
    call    SPR_Pixel
    pop     rsi
    pop     rax
    mov     ecx, r14d
    add     ecx, eax
    mov     edx, esi
    mov     r8d, PAL_RED + 1
    call    SPR_Pixel
    jmp     .done

; ================================ туша =====================================
.blob:
    mov     eax, [cr_h]
    shr     eax, 1
    mov     ebx, eax
    mov     eax, [cr_body]
    add     eax, 4
    mov     [sp_color], eax
    add     eax, 9
    mov     [sp_edge], eax
    mov     ecx, r14d
    mov     edx, r15d
    sub     edx, ebx
    mov     r8d, [cr_bw]
    shr     r8d, 1
    mov     r9d, ebx
    call    SPR_Ellipse
    ; лапы
    mov     eax, r12d
    and     eax, 3
    mov     esi, [legphase + rax*4]
    mov     eax, [cr_body]
    add     eax, 12
    mov     [sp_color], eax
    add     eax, 5
    mov     [sp_edge], eax
    mov     eax, [cr_bw]
    mov     ecx, 4
    xor     edx, edx
    div     ecx
    mov     edi, eax                    ; вынос лап
    mov     ecx, r14d
    sub     ecx, edi
    add     ecx, esi
    mov     edx, r15d
    dec     edx
    mov     r8d, 3
    mov     r9d, 3
    call    SPR_Ellipse
    mov     ecx, r14d
    add     ecx, edi
    sub     ecx, esi
    mov     edx, r15d
    dec     edx
    mov     r8d, 3
    mov     r9d, 3
    call    SPR_Ellipse
    ; пасть анфас
    cmp     r13d, 0
    jne     .done
    mov     dword [sp_color], PAL_RED + 2
    mov     dword [sp_edge], PAL_RED + 11
    mov     ecx, r14d
    mov     edx, r15d
    sub     edx, ebx
    add     edx, 3
    mov     r8d, [cr_bw]
    shr     r8d, 2
    mov     r9d, 4
    call    SPR_Ellipse
    ; клыки
    mov     ecx, r14d
    sub     ecx, 3
    mov     edx, r15d
    sub     edx, ebx
    add     edx, 1
    mov     r8d, PAL_TAN + 1
    call    SPR_Pixel
    mov     ecx, r14d
    add     ecx, 3
    mov     edx, r15d
    sub     edx, ebx
    add     edx, 1
    mov     r8d, PAL_TAN + 1
    call    SPR_Pixel
    jmp     .done

; =========================== парящая голова ================================
.float:
    mov     eax, [cr_h]
    shr     eax, 1
    mov     ebx, eax
    mov     eax, [cr_body]
    add     eax, 3
    mov     [sp_color], eax
    add     eax, 11
    mov     [sp_edge], eax
    mov     ecx, r14d
    mov     edx, r15d
    sub     edx, ebx
    mov     r8d, [cr_bw]
    shr     r8d, 1
    mov     r9d, ebx
    call    SPR_Ellipse
    ; рога
    mov     eax, [cr_head]
    mov     [sp_color], eax
    add     eax, 7
    mov     [sp_edge], eax
    mov     eax, [cr_bw]
    shr     eax, 1
    mov     edi, eax
    mov     ecx, r14d
    sub     ecx, edi
    mov     edx, r15d
    sub     edx, ebx
    mov     eax, ebx
    shr     eax, 1
    sub     edx, eax
    mov     r8d, 3
    mov     r9d, 2
    call    SPR_Ellipse
    mov     ecx, r14d
    add     ecx, edi
    mov     edx, r15d
    sub     edx, ebx
    mov     eax, ebx
    shr     eax, 1
    sub     edx, eax
    mov     r8d, 3
    mov     r9d, 2
    call    SPR_Ellipse
    ; глаз
    cmp     r13d, 0
    jne     .done
    mov     dword [sp_color], PAL_YELLOW
    mov     dword [sp_edge], PAL_ORANGE + 5
    mov     ecx, r14d
    mov     edx, r15d
    sub     edx, ebx
    mov     r8d, 5
    mov     r9d, 4
    call    SPR_Ellipse
    mov     ecx, r14d
    mov     edx, r15d
    sub     edx, ebx
    mov     r8d, PAL_RED + 1
    call    SPR_Pixel
    jmp     .done

; ============================ кадры смерти =================================
.dead:
    mov     eax, r12d
    sub     eax, 7                      ; 1..5
    mov     esi, eax
    ; тело оседает и растекается
    mov     eax, [cr_h]
    imul    eax, esi
    mov     ecx, 12
    xor     edx, edx
    div     ecx
    mov     ebx, eax
    mov     eax, [cr_h]
    shr     eax, 1
    sub     eax, ebx
    cmp     eax, 3
    jge     .dh
    mov     eax, 3
.dh:
    mov     edi, eax                    ; полувысота останков
    mov     eax, [cr_bw]
    shr     eax, 1
    imul    eax, esi
    shr     eax, 2
    add     eax, [cr_bw]
    shr     eax, 1                      ; растекание вширь
    mov     r8d, eax
    mov     eax, [cr_body]
    add     eax, 8
    mov     [sp_color], eax
    add     eax, 8
    mov     [sp_edge], eax
    mov     ecx, r14d
    mov     edx, r15d
    sub     edx, edi
    mov     r9d, edi
    call    SPR_Ellipse
    ; лужа крови растёт
    cmp     esi, 2
    jl      .done
    mov     dword [sp_color], PAL_RED + 6
    mov     dword [sp_edge], PAL_RED + 14
    mov     eax, [cr_bw]
    imul    eax, esi
    mov     ecx, 8
    xor     edx, edx
    div     ecx
    mov     r8d, eax
    mov     ecx, r14d
    mov     edx, r15d
    dec     edx
    mov     r9d, 2
    call    SPR_Ellipse
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
;  R_MakeItem -- предметы (1 ракурс, несколько кадров мигания)
; ---------------------------------------------------------------------------
R_MakeItem:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    xor     r12d, r12d
.frameloop:
    mov     ecx, [cr_h]
    add     ecx, 6
    mov     edx, [cr_h]
    add     edx, 6
    call    SPR_Begin
    ; яркость по кадру
    mov     eax, [cr_body]
    mov     ecx, r12d
    and     ecx, 3
    add     eax, ecx
    mov     [sp_color], eax
    add     eax, 6
    mov     [sp_edge], eax
    mov     r13d, [cr_style]
    mov     ecx, [bake_w]
    shr     ecx, 1
    mov     edx, [bake_h]
    shr     edx, 1
    add     edx, 1
    cmp     r13d, 0
    jne     .box
    ; шар
    mov     r8d, [cr_h]
    shr     r8d, 1
    mov     r9d, r8d
    call    SPR_Ellipse
    jmp     .bake
.box:
    cmp     r13d, 1
    jne     .flat
    ; коробка
    mov     eax, [cr_h]
    shr     eax, 1
    mov     r8d, ecx
    add     r8d, eax
    mov     r9d, edx
    add     r9d, eax
    sub     ecx, eax
    sub     edx, eax
    call    SPR_Rect
    jmp     .bake
.flat:
    ; плоский предмет (карта/ключ)
    mov     eax, [cr_h]
    shr     eax, 1
    mov     r8d, ecx
    add     r8d, 2
    mov     r9d, edx
    add     r9d, eax
    sub     ecx, 2
    sub     edx, eax
    call    SPR_Rect
    mov     ecx, [bake_w]
    shr     ecx, 1
    mov     edx, [bake_h]
    shr     edx, 1
    mov     r8d, [cr_h]
    shr     r8d, 2
    mov     r9d, r8d
    call    SPR_Ellipse
.bake:
    mov     ecx, [bake_w]
    shr     ecx, 1
    mov     edx, [bake_h]
    call    SPR_Bake
    mov     r9, rax
    mov     ecx, [cr_spr]
    mov     edx, r12d
    xor     r8d, r8d
    call    R_SetSprite
    ; все ракурсы одинаковы
    mov     r8d, 1
.rl:
    mov     ecx, [cr_spr]
    mov     edx, r12d
    call    R_SetSprite
    inc     r8d
    cmp     r8d, 8
    jb      .rl
    inc     r12d
    cmp     r12d, [cr_w]                ; число кадров
    jb      .frameloop
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_MakeEffects -- снаряды, вспышки, кровь, туман
; ---------------------------------------------------------------------------
R_MakeEffects:
    push    rbx
    push    rsi
    push    r12
    push    r13
    xor     r12d, r12d
.l:
    imul    eax, r12d, 4
    lea     rsi, [effectdefs]
    add     rsi, rax
    movzx   r13d, byte [rsi + 0]
    cmp     r13d, 255
    je      .done
    movzx   eax, byte [rsi + 1]
    mov     [cr_body], eax
    movzx   eax, byte [rsi + 2]
    mov     [cr_h], eax                 ; базовый радиус
    movzx   eax, byte [rsi + 3]
    mov     [cr_w], eax                 ; число кадров
    mov     [cr_spr], r13d
    xor     ebx, ebx
.fl:
    mov     ecx, 40
    mov     edx, 40
    call    SPR_Begin
    ; радиус растёт по кадрам
    mov     eax, [cr_h]
    mov     ecx, ebx
    imul    ecx, eax
    shr     ecx, 2
    add     eax, ecx
    mov     r8d, eax
    mov     r9d, eax
    mov     eax, [cr_body]
    add     eax, ebx
    mov     [sp_color], eax
    add     eax, 5
    mov     [sp_edge], eax
    mov     ecx, 20
    mov     edx, 20
    call    SPR_Ellipse
    mov     ecx, 20
    mov     edx, 32
    call    SPR_Bake
    mov     r9, rax
    xor     r8d, r8d
.rr:
    mov     ecx, [cr_spr]
    mov     edx, ebx
    call    R_SetSprite
    inc     r8d
    cmp     r8d, 8
    jb      .rr
    inc     ebx
    cmp     ebx, [cr_w]
    jb      .fl
    inc     r12d
    jmp     .l
.done:
    pop     r13
    pop     r12
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_MakeWeapons -- графика оружия в руках
; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
;  R_MakeWeapons -- графика оружия в руках из таблицы прямоугольников
;  Формат: db спрайт; далее записи db x0,y0,x1,y1,цвет; 255 -- конец оружия;
;  255 вместо номера спрайта -- конец таблицы.
;  Каждый прямоугольник рисуется с фаской: верхняя строка светлее, нижняя темнее.
; ---------------------------------------------------------------------------
R_MakeWeapons:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    lea     rsi, [weapshapes]
.wloop:
    movzx   r13d, byte [rsi]
    cmp     r13d, 255
    je      .done
    inc     rsi
    mov     [cr_spr], r13d
    mov     r14, rsi                    ; начало списка фигур
    xor     ebx, ebx                    ; кадр
.floop:
    mov     ecx, 100
    mov     edx, 128
    call    SPR_Begin
    ; отдача по кадрам: 0 -6 -3 0
    imul    eax, ebx, 4
    lea     rdi, [weaprecoil]
    movsx   r15d, byte [rdi + rax]
    mov     rsi, r14
.shape:
    movzx   eax, byte [rsi]
    cmp     eax, 255
    je      .shapedone
    movzx   ecx, byte [rsi + 0]         ; x0
    movzx   edx, byte [rsi + 1]         ; y0
    add     edx, r15d
    movzx   r8d, byte [rsi + 2]         ; x1
    movzx   r9d, byte [rsi + 3]         ; y1
    add     r9d, r15d
    movzx   eax, byte [rsi + 4]         ; цвет
    mov     [sp_color], eax
    push    rsi
    push    rcx
    push    rdx
    push    r8
    push    r9
    call    SPR_Rect
    ; светлая кромка сверху
    pop     r9
    pop     r8
    pop     rdx
    pop     rcx
    push    rcx
    push    rdx
    push    r8
    push    r9
    mov     eax, [sp_color]
    sub     eax, 2
    mov     [sp_color], eax
    mov     r9d, edx
    call    SPR_Rect
    ; тень снизу
    pop     r9
    pop     r8
    pop     rdx
    pop     rcx
    mov     eax, [sp_color]
    add     eax, 6
    mov     [sp_color], eax
    mov     edx, r9d
    call    SPR_Rect
    pop     rsi
    add     rsi, 5
    jmp     .shape
.shapedone:
    mov     ecx, -110
    xor     edx, edx
    call    SPR_Bake
    mov     r9, rax
    xor     r8d, r8d
.rr:
    mov     ecx, [cr_spr]
    mov     edx, ebx
    call    R_SetSprite
    inc     r8d
    cmp     r8d, 8
    jb      .rr
    inc     ebx
    cmp     ebx, 4
    jb      .floop
    ; перейти к следующему оружию
    mov     rsi, r14
.skip:
    movzx   eax, byte [rsi]
    cmp     eax, 255
    je      .skipdone
    add     rsi, 5
    jmp     .skip
.skipdone:
    inc     rsi
    jmp     .wloop
.done:
    ; вспышка ствола -- отдельный светящийся блик
    mov     ecx, SPR_FLSH
    mov     [cr_spr], ecx
    xor     ebx, ebx
.fl:
    mov     ecx, 100
    mov     edx, 128
    call    SPR_Begin
    mov     eax, PAL_YELLOW
    add     eax, ebx
    mov     [sp_color], eax
    mov     eax, PAL_ORANGE + 4
    mov     [sp_edge], eax
    mov     ecx, 50
    mov     edx, 46
    mov     r8d, 13
    mov     r9d, 10
    call    SPR_Ellipse
    mov     dword [sp_color], PAL_TAN
    mov     dword [sp_edge], PAL_YELLOW + 2
    mov     ecx, 50
    mov     edx, 46
    mov     r8d, 6
    mov     r9d, 5
    call    SPR_Ellipse
    mov     ecx, -110
    xor     edx, edx
    call    SPR_Bake
    mov     r9, rax
    xor     r8d, r8d
.fr:
    mov     ecx, [cr_spr]
    mov     edx, ebx
    call    R_SetSprite
    inc     r8d
    cmp     r8d, 8
    jb      .fr
    inc     ebx
    cmp     ebx, 2
    jb      .fl
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ===========================================================================
;  Отрисовка спрайтов
; ===========================================================================
R_ClearSprites:
    push    rbx
    mov     dword [numvissprites], 0
    xor     ebx, ebx
.l: mov     byte [secspr + rbx], 0
    inc     ebx
    cmp     ebx, MAXSECTORS
    jb      .l
    pop     rbx
    ret

; R_DrawMaskedColumn(rcx = данные столбца)
R_DrawMaskedColumn:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    mov     rsi, rcx
    mov     r12d, [dc_texturemid]       ; базовая середина
.postloop:
    movzx   eax, byte [rsi]
    cmp     eax, 0xff
    je      .done
    mov     r13d, eax                   ; topdelta
    movzx   r14d, byte [rsi + 1]        ; длина
    ; topscreen = sprtopscreen + spryscale*topdelta
    mov     eax, [spryscale]
    imul    eax, r13d
    add     eax, [sprtopscreen]
    mov     ebx, eax                    ; topscreen
    mov     eax, [spryscale]
    imul    eax, r14d
    add     eax, ebx                    ; bottomscreen
    mov     edi, eax
    lea     eax, [rbx + FRACUNIT-1]
    sar     eax, FRACBITS
    mov     [dc_yl], eax
    lea     eax, [rdi - 1]
    sar     eax, FRACBITS
    mov     [dc_yh], eax
    ; отсечение
    mov     rcx, [mfloorclip]
    mov     eax, [dc_x]
    mov     ecx, [rcx + rax*4]
    cmp     [dc_yh], ecx
    jl      .yh_ok
    dec     ecx
    mov     [dc_yh], ecx
.yh_ok:
    mov     rcx, [mceilingclip]
    mov     eax, [dc_x]
    mov     ecx, [rcx + rax*4]
    cmp     [dc_yl], ecx
    jg      .yl_ok
    inc     ecx
    mov     [dc_yl], ecx
.yl_ok:
    mov     eax, [dc_yl]
    cmp     eax, [dc_yh]
    jg      .nextpost
    lea     rax, [rsi + 3]
    mov     [dc_source], rax
    mov     eax, r13d
    shl     eax, FRACBITS
    mov     ecx, r12d
    sub     ecx, eax
    mov     [dc_texturemid], ecx
    mov     dword [dc_texmask], 255
    call    R_DrawColumn
    mov     [dc_texturemid], r12d
.nextpost:
    lea     rsi, [rsi + r14 + 4]
    jmp     .postloop
.done:
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_AddSprites(ecx = сектор) -- собрать видимые объекты сектора
; ---------------------------------------------------------------------------
R_AddSprites:
    push    rbx
    push    rsi
    push    r12
    cmp     byte [secspr + rcx], 0
    jne     .ret
    mov     byte [secspr + rcx], 1
    imul    esi, ecx, SECTOR_SIZE
    ; уровень освещения для спрайтов
    mov     eax, [sectors + rsi + SEC_LIGHT]
    sar     eax, LIGHTSEGSHIFT
    add     eax, [extralight]
    test    eax, eax
    jns     .l1
    xor     eax, eax
.l1:
    cmp     eax, LIGHTLEVELS
    jl      .l2
    mov     eax, LIGHTLEVELS-1
.l2:
    imul    eax, MAXLIGHTSCALE*8
    lea     rdx, [scalelight]
    add     rdx, rax
    mov     [spritelights], rdx
    mov     rbx, [sectors + rsi + SEC_THINGLIST]
.l:
    test    rbx, rbx
    jz      .done
    mov     rcx, rbx
    call    R_ProjectSprite
    mov     rbx, [rbx + MO_SNEXT]
    jmp     .l
.done:
.ret:
    pop     r12
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_ProjectSprite(rcx = mobj)
; ---------------------------------------------------------------------------
R_ProjectSprite:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rcx
    ; координаты относительно наблюдателя
    mov     ecx, [rbx + MO_X]
    sub     ecx, [viewx]
    mov     r12d, ecx                   ; tr_x
    mov     ecx, [rbx + MO_Y]
    sub     ecx, [viewy]
    mov     r13d, ecx                   ; tr_y
    mov     ecx, r12d
    mov     edx, [viewcos]
    call    FixedMul
    mov     esi, eax                    ; gxt
    mov     ecx, r13d
    mov     edx, [viewsin]
    call    FixedMul
    neg     eax
    mov     edi, eax                    ; gyt
    mov     r14d, esi
    sub     r14d, edi                   ; tz
    cmp     r14d, MINZ
    jl      .done
    mov     ecx, [projection]
    mov     edx, r14d
    call    FixedDiv
    mov     r15d, eax                   ; xscale
    ; tx
    mov     ecx, r12d
    mov     edx, [viewsin]
    call    FixedMul
    neg     eax
    mov     esi, eax
    mov     ecx, r13d
    mov     edx, [viewcos]
    call    FixedMul
    add     eax, esi
    neg     eax
    mov     esi, eax                    ; tx
    ; за пределами поля зрения
    mov     eax, esi
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    mov     ecx, r14d
    shl     ecx, 2
    cmp     eax, ecx
    jg      .done

    ; выбор кадра и ракурса
    mov     ecx, [rbx + MO_SPRITE]
    mov     edx, [rbx + MO_FRAME]
    and     edx, FF_FRAMEMASK
    ; ракурс
    mov     eax, [rbx + MO_X]
    push    rcx
    push    rdx
    mov     ecx, eax
    mov     edx, [rbx + MO_Y]
    call    R_PointToAngle
    sub     eax, [rbx + MO_ANGLE]
    add     eax, (ANG45/2)*9
    shr     eax, 29
    mov     r8d, eax
    pop     rdx
    pop     rcx
    call    R_GetSprite
    test    rax, rax
    jnz     .havepatch
    ; нет такого ракурса -- берём нулевой
    mov     ecx, [rbx + MO_SPRITE]
    mov     edx, [rbx + MO_FRAME]
    and     edx, FF_FRAMEMASK
    xor     r8d, r8d
    call    R_GetSprite
    test    rax, rax
    jz      .done
.havepatch:
    mov     rdi, rax                    ; патч
    ; границы по X
    mov     eax, [rdi + PA_LEFT]
    shl     eax, FRACBITS
    sub     esi, eax
    mov     ecx, esi
    mov     edx, r15d
    call    FixedMul
    add     eax, [centerxfrac]
    sar     eax, FRACBITS
    mov     r12d, eax                   ; x1
    cmp     r12d, [viewwidth]
    jg      .done
    mov     eax, [rdi + PA_WIDTH]
    shl     eax, FRACBITS
    add     esi, eax
    mov     ecx, esi
    mov     edx, r15d
    call    FixedMul
    add     eax, [centerxfrac]
    sar     eax, FRACBITS
    dec     eax
    mov     r13d, eax                   ; x2
    test    r13d, r13d
    js      .done

    ; новый vissprite
    mov     eax, [numvissprites]
    cmp     eax, MAXVISSPRITES
    jae     .done
    inc     dword [numvissprites]
    imul    eax, VS_SIZE
    lea     rsi, [vissprites]
    add     rsi, rax
    mov     eax, [rbx + MO_FLAGS]
    mov     [rsi + VS_FLAGS], eax
    mov     [rsi + VS_SCALE], r15d
    mov     eax, [rbx + MO_X]
    mov     [rsi + VS_GX], eax
    mov     eax, [rbx + MO_Y]
    mov     [rsi + VS_GY], eax
    mov     eax, [rbx + MO_Z]
    mov     [rsi + VS_GZ], eax
    mov     eax, [rdi + PA_TOP]
    shl     eax, FRACBITS
    add     eax, [rbx + MO_Z]
    mov     [rsi + VS_GZT], eax
    sub     eax, [viewz]
    mov     [rsi + VS_TEXMID], eax
    mov     eax, r12d
    test    eax, eax
    jns     .x1ok
    xor     eax, eax
.x1ok:
    mov     [rsi + VS_X1], eax
    mov     ecx, [viewwidth]
    dec     ecx
    cmp     r13d, ecx
    jle     .x2ok
    mov     r13d, ecx
.x2ok:
    mov     [rsi + VS_X2], r13d
    mov     [rsi + VS_PATCH], rdi
    ; шаг по текстуре
    mov     ecx, FRACUNIT
    mov     edx, r15d
    call    FixedDiv
    mov     [rsi + VS_XISCALE], eax
    mov     dword [rsi + VS_STARTFRAC], 0
    mov     ecx, [rsi + VS_X1]
    sub     ecx, r12d
    jle     .nofrac
    imul    ecx, eax
    mov     [rsi + VS_STARTFRAC], ecx
.nofrac:
    ; освещение
    test    dword [rbx + MO_FLAGS], MF_SHADOW
    jz      .nofuzz
    mov     qword [rsi + VS_COLORMAP], 0
    jmp     .done
.nofuzz:
    mov     rax, [fixedcolormap]
    test    rax, rax
    jz      .nofixed
    mov     [rsi + VS_COLORMAP], rax
    jmp     .done
.nofixed:
    test    dword [rbx + MO_FRAME], FF_FULLBRIGHT
    jz      .normallight
    lea     rax, [colormaps]
    mov     [rsi + VS_COLORMAP], rax
    jmp     .done
.normallight:
    mov     eax, r15d
    sar     eax, LIGHTSCALESHIFT
    cmp     eax, MAXLIGHTSCALE
    jb      .lok
    mov     eax, MAXLIGHTSCALE-1
.lok:
    mov     rdx, [spritelights]
    mov     rax, [rdx + rax*8]
    mov     [rsi + VS_COLORMAP], rax
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_DrawVisSprite(rsi = vissprite)
; ---------------------------------------------------------------------------
R_DrawVisSprite:
    push    rbx
    push    rdi
    push    r12
    push    r13
    mov     rdi, [rsi + VS_PATCH]
    mov     rax, [rsi + VS_COLORMAP]
    mov     [dc_colormap], rax
    test    rax, rax
    jnz     .nofuzz
    lea     rax, [colormaps]
    mov     [dc_colormap], rax
.nofuzz:
    mov     eax, [rsi + VS_TEXMID]
    mov     [dc_texturemid], eax
    mov     eax, [rsi + VS_XISCALE]
    mov     [dc_iscale], eax
    mov     eax, [rsi + VS_SCALE]
    mov     [spryscale], eax
    mov     ecx, [rsi + VS_TEXMID]
    mov     edx, eax
    call    FixedMul
    mov     ecx, [centeryfrac]
    sub     ecx, eax
    mov     [sprtopscreen], ecx
    mov     r12d, [rsi + VS_X1]
    mov     r13d, [rsi + VS_STARTFRAC]
.col:
    cmp     r12d, [rsi + VS_X2]
    jg      .done
    mov     eax, r13d
    sar     eax, FRACBITS
    cmp     eax, 0
    jl      .next
    cmp     eax, [rdi + PA_WIDTH]
    jge     .next
    mov     [dc_x], r12d
    mov     ecx, [rdi + PA_COLOFS + rax*4]
    lea     rcx, [rdi + rcx]
    cmp     qword [rsi + VS_COLORMAP], 0
    jne     .normal
    push    rsi
    push    rdi
    call    R_DrawMaskedFuzz
    pop     rdi
    pop     rsi
    jmp     .next
.normal:
    push    rsi
    push    rdi
    call    R_DrawMaskedColumn
    pop     rdi
    pop     rsi
.next:
    add     r13d, [rsi + VS_XISCALE]
    inc     r12d
    jmp     .col
.done:
    pop     r13
    pop     r12
    pop     rdi
    pop     rbx
    ret

; призрачный столбец
R_DrawMaskedFuzz:
    push    rbx
    push    rsi
    push    r14
    mov     rsi, rcx
.postloop:
    movzx   eax, byte [rsi]
    cmp     eax, 0xff
    je      .done
    mov     ebx, eax
    movzx   r14d, byte [rsi + 1]
    mov     eax, [spryscale]
    imul    eax, ebx
    add     eax, [sprtopscreen]
    mov     ecx, eax
    mov     eax, [spryscale]
    imul    eax, r14d
    add     eax, ecx
    lea     edx, [rcx + FRACUNIT-1]
    sar     edx, FRACBITS
    mov     [dc_yl], edx
    dec     eax
    sar     eax, FRACBITS
    mov     [dc_yh], eax
    mov     rcx, [mfloorclip]
    mov     eax, [dc_x]
    mov     ecx, [rcx + rax*4]
    cmp     [dc_yh], ecx
    jl      .yh
    dec     ecx
    mov     [dc_yh], ecx
.yh:
    mov     rcx, [mceilingclip]
    mov     eax, [dc_x]
    mov     ecx, [rcx + rax*4]
    cmp     [dc_yl], ecx
    jg      .yl
    inc     ecx
    mov     [dc_yl], ecx
.yl:
    mov     eax, [dc_yl]
    cmp     eax, [dc_yh]
    jg      .next
    push    rsi
    call    R_DrawFuzzColumn
    pop     rsi
.next:
    lea     rsi, [rsi + r14 + 4]
    jmp     .postloop
.done:
    pop     r14
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_DrawSprite(rsi = vissprite) -- с отсечением по drawseg'ам
; ---------------------------------------------------------------------------
R_DrawSprite:
    push    rbx
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    ; изначально клип = экран
    mov     r12d, [rsi + VS_X1]
    mov     r13d, [rsi + VS_X2]
    mov     ebx, r12d
.initclip:
    mov     dword [clipbot + rbx*4], -2
    mov     dword [cliptop + rbx*4], -2
    inc     ebx
    cmp     ebx, r13d
    jle     .initclip

    ; проход по drawseg'ам от ближних к дальним
    mov     r14d, [ds_index]
.dsloop:
    dec     r14d
    js      .dsdone
    imul    eax, r14d, DRAWSEG_SIZE
    lea     rdi, [drawsegs]
    add     rdi, rax
    mov     eax, [rdi + DS_X1]
    cmp     eax, r13d
    jg      .dsloop
    mov     eax, [rdi + DS_X2]
    cmp     eax, r12d
    jl      .dsloop
    ; диапазон пересечения
    mov     r15d, [rdi + DS_X1]
    cmp     r15d, r12d
    jge     .r1
    mov     r15d, r12d
.r1:
    mov     ebx, [rdi + DS_X2]
    cmp     ebx, r13d
    jle     .r2
    mov     ebx, r13d
.r2:
    ; отрезок без силуэта ничего не закрывает
    cmp     dword [rdi + DS_SILHOUETTE], 0
    je      .dsloop
    ; масштаб отрезка: если он дальше спрайта -- пропускаем
    mov     eax, [rdi + DS_SCALE1]
    mov     ecx, [rdi + DS_SCALE2]
    cmp     eax, ecx
    jge     .havescale
    mov     eax, ecx
.havescale:
    cmp     eax, [rsi + VS_SCALE]
    jl      .dsloop                     ; вся стена дальше спрайта
    ; ближний конец ближе; проверим дальний
    mov     eax, [rdi + DS_SCALE1]
    mov     ecx, [rdi + DS_SCALE2]
    cmp     eax, ecx
    jle     .havelow
    mov     eax, ecx
.havelow:
    cmp     eax, [rsi + VS_SCALE]
    jge     .silhouette                 ; вся стена ближе -- отсекаем
    ; стена наискось: если спрайт с той же стороны, что и наблюдатель -- она сзади
    mov     r8d, [rdi + DS_LINEOFS]
    mov     ecx, [rsi + VS_GX]
    mov     edx, [rsi + VS_GY]
    call    P_PointOnLineSide
    push    rax
    mov     r8d, [rdi + DS_LINEOFS]
    mov     ecx, [viewx]
    mov     edx, [viewy]
    call    P_PointOnLineSide
    pop     rcx
    cmp     eax, ecx
    je      .dsloop
.silhouette:
    mov     eax, [rdi + DS_SILHOUETTE]
    test    eax, SIL_BOTTOM
    jz      .notbot
    mov     r8, [rdi + DS_SPRBOTCLIP]
    test    r8, r8
    jz      .notbot
    push    rbx
    mov     ebx, r15d
.botloop:
    cmp     dword [clipbot + rbx*4], -2
    jne     .botnext
    mov     eax, [r8 + rbx*4]
    mov     [clipbot + rbx*4], eax
.botnext:
    inc     ebx
    cmp     ebx, [rsp]
    jle     .botloop
    pop     rbx
.notbot:
    mov     eax, [rdi + DS_SILHOUETTE]
    test    eax, SIL_TOP
    jz      .nottop
    mov     r8, [rdi + DS_SPRTOPCLIP]
    test    r8, r8
    jz      .nottop
    push    rbx
    mov     ebx, r15d
.toploop:
    cmp     dword [cliptop + rbx*4], -2
    jne     .topnext
    mov     eax, [r8 + rbx*4]
    mov     [cliptop + rbx*4], eax
.topnext:
    inc     ebx
    cmp     ebx, [rsp]
    jle     .toploop
    pop     rbx
.nottop:
    jmp     .dsloop
.dsdone:
    ; незаполненные -- границы экрана
    mov     ebx, r12d
.fill:
    cmp     dword [clipbot + rbx*4], -2
    jne     .f1
    mov     eax, [viewheight]
    mov     [clipbot + rbx*4], eax
.f1:
    cmp     dword [cliptop + rbx*4], -2
    jne     .f2
    mov     dword [cliptop + rbx*4], -1
.f2:
    inc     ebx
    cmp     ebx, r13d
    jle     .fill
    lea     rax, [clipbot]
    mov     [mfloorclip], rax
    lea     rax, [cliptop]
    mov     [mceilingclip], rax
    call    R_DrawVisSprite
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_DrawMasked -- спрайты (дальние сначала) и оружие
; ---------------------------------------------------------------------------
R_DrawMasked:

    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
.loop:
    ; ищем самый дальний ещё не нарисованный
    mov     r12d, -1
    mov     r13d, MAXINT
    xor     ebx, ebx
.find:
    cmp     ebx, [numvissprites]
    jae     .founddone
    imul    eax, ebx, VS_SIZE
    lea     rsi, [vissprites]
    add     rsi, rax
    cmp     dword [rsi + VS_SCALE], 0
    jle     .findnext
    cmp     dword [rsi + VS_SCALE], r13d
    jge     .findnext
    mov     r13d, [rsi + VS_SCALE]
    mov     r12d, ebx
.findnext:
    inc     ebx
    jmp     .find
.founddone:
    cmp     r12d, -1
    je      .spritesdone
    imul    eax, r12d, VS_SIZE
    lea     rsi, [vissprites]
    add     rsi, rax
    call    R_DrawSprite
    imul    eax, r12d, VS_SIZE
    lea     rsi, [vissprites]
    add     rsi, rax
    mov     dword [rsi + VS_SCALE], 0   ; помечаем нарисованным
    jmp     .loop
.spritesdone:
    call    R_DrawPlayerSprites
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_DrawPlayerSprites -- оружие в руках
; ---------------------------------------------------------------------------
R_DrawPlayerSprites:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    ; освещение
    mov     rax, [fixedcolormap]
    test    rax, rax
    jz      .nofixed
    mov     [dc_colormap], rax
    jmp     .haveclip
.nofixed:
    mov     eax, [viewsector]
    cmp     eax, -1
    je      .deflight
    imul    eax, SECTOR_SIZE
    mov     eax, [sectors + rax + SEC_LIGHT]
    sar     eax, LIGHTSEGSHIFT
    add     eax, [extralight]
    test    eax, eax
    jns     .cl1
    xor     eax, eax
.cl1:
    cmp     eax, LIGHTLEVELS
    jl      .cl2
    mov     eax, LIGHTLEVELS-1
.cl2:
    imul    eax, MAXLIGHTSCALE*8
    lea     rdx, [scalelight]
    add     rdx, rax
    mov     rax, [rdx + (MAXLIGHTSCALE-1)*8]
    mov     [dc_colormap], rax
    jmp     .haveclip
.deflight:
    lea     rax, [colormaps]
    mov     [dc_colormap], rax
.haveclip:
    ; клип по всему экрану
    xor     ebx, ebx
.clip:
    mov     eax, [viewheight]
    mov     [clipbot + rbx*4], eax
    mov     dword [cliptop + rbx*4], -1
    inc     ebx
    cmp     ebx, SCREENWIDTH
    jb      .clip
    lea     rax, [clipbot]
    mov     [mfloorclip], rax
    lea     rax, [cliptop]
    mov     [mceilingclip], rax

    xor     r12d, r12d
.psploop:
    imul    ebx, r12d, PSPDEF_SIZE
    add     rbx, player + PL_PSPRITES
    mov     rax, [rbx + PSP_STATE]
    test    rax, rax
    jz      .pspnext
    mov     ecx, [rax + ST_SPRITE]
    mov     edx, [rax + ST_FRAME]
    and     edx, FF_FRAMEMASK
    xor     r8d, r8d
    push    rax
    call    R_GetSprite
    pop     rdx
    test    rax, rax
    jz      .pspnext
    mov     rdi, rax
    ; полная яркость для вспышек
    test    dword [rdx + ST_FRAME], FF_FULLBRIGHT
    jz      .nofull
    lea     rax, [colormaps]
    mov     [dc_colormap], rax
.nofull:
    ; положение
    mov     eax, [rbx + PSP_SX]
    mov     ecx, [rdi + PA_LEFT]
    shl     ecx, FRACBITS
    sub     eax, ecx
    sar     eax, FRACBITS
    add     eax, [centerx]
    sub     eax, 160
    mov     esi, eax                    ; x1
    ; texturemid = 100.5 - (sy - topoffset)
    mov     eax, [rdi + PA_TOP]
    shl     eax, FRACBITS
    mov     ecx, [rbx + PSP_SY]
    sub     ecx, eax
    mov     eax, 100*FRACUNIT + FRACUNIT/2
    sub     eax, ecx
    mov     [dc_texturemid], eax
    mov     ecx, [centeryfrac]
    sub     ecx, eax
    mov     [sprtopscreen], ecx
    mov     dword [dc_iscale], FRACUNIT
    mov     dword [spryscale], FRACUNIT
    xor     r8d, r8d
.pcol:
    cmp     r8d, [rdi + PA_WIDTH]
    jae     .pspnext
    mov     eax, esi
    add     eax, r8d
    cmp     eax, 0
    jl      .pcolnext
    cmp     eax, SCREENWIDTH
    jge     .pcolnext
    mov     [dc_x], eax
    mov     ecx, [rdi + PA_COLOFS + r8*4]
    lea     rcx, [rdi + rcx]
    push    r8
    push    rsi
    push    rdi
    call    R_DrawMaskedColumn
    pop     rdi
    pop     rsi
    pop     r8
.pcolnext:
    inc     r8d
    jmp     .pcol
.pspnext:
    inc     r12d
    cmp     r12d, NUMPSPRITES
    jb      .psploop
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
