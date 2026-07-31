; ===========================================================================
;  r_tex.asm -- процедурные текстуры стен, флэты пола/потолка и небо
;
;  Текстуры хранятся по столбцам (как в DOOM), флэты 64x64 по строкам.
; ===========================================================================

%define TX_WIDTH    0
%define TX_HEIGHT   4
%define TX_WMASK    8
%define TX_HMASK    12
%define TX_DATA     16
%define TX_HFRAC    24
%define TX_SIZE     32

%define TEX_NONE        0
%define TEX_TEK1        1
%define TEX_BROWN       2
%define TEX_STARTAN     3
%define TEX_DOORTRAK    4
%define TEX_BIGDOOR     5
%define TEX_SWITCH1     6
%define TEX_SWITCH2     7
%define TEX_COMP        8
%define TEX_DOORBLU     9
%define TEX_DOORYEL     10
%define TEX_DOORRED     11
%define TEX_EXITDOOR    12
%define TEX_GSTONE      13
%define TEX_MARBLE      14
%define TEX_SUPPORT     15
%define TEX_LITE        16
%define TEX_METAL       17
%define TEX_STEP        18
%define TEX_BLOODWALL   19
%define TEX_SKYTEX      20
%define NUMTEXTURES     21

%define FLAT_FLOOR      0
%define FLAT_BROWN      1
%define FLAT_CEIL       2
%define FLAT_NUKAGE1    3
%define FLAT_NUKAGE2    4
%define FLAT_NUKAGE3    5
%define FLAT_BLOOD1     6
%define FLAT_BLOOD2     7
%define FLAT_BLOOD3     8
%define FLAT_GRATE      9
%define FLAT_LIGHT      10
%define FLAT_STEP       11
%define FLAT_SKY        12
%define FLAT_CARPET     13
%define FLAT_ROCK       14
%define NUMFLATS        15

; ---------------------------------------------------------------------------
;  R_Rand -> eax (0..65535), простой ЛКГ для генерации текстур
; ---------------------------------------------------------------------------
R_Rand:
    mov     eax, [texrandseed]
    imul    eax, 1103515245
    add     eax, 12345
    mov     [texrandseed], eax
    shr     eax, 8
    and     eax, 0xffff
    ret

; R_Noise(ecx=x, edx=y) -> eax 0..255
R_Noise:
    mov     eax, ecx
    imul    eax, 374761393
    mov     r8d, edx
    imul    r8d, 668265263
    add     eax, r8d
    mov     r8d, eax
    shr     r8d, 13
    xor     eax, r8d
    imul    eax, 1274126177
    mov     r8d, eax
    shr     r8d, 16
    xor     eax, r8d
    and     eax, 255
    ret

; ---------------------------------------------------------------------------
;  R_InitTextures
; ---------------------------------------------------------------------------
R_InitTextures:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13

    mov     dword [texrandseed], 12345
    mov     dword [skyflatnum], FLAT_SKY
    mov     dword [skytexture], TEX_SKYTEX

    ; --- выделение памяти под текстуры ---
    xor     ebx, ebx
.alloc:
    imul    r12d, ebx, 8
    lea     rsi, [texdefs]
    add     rsi, r12
    movzx   r13d, byte [rsi + 0]        ; ширина/8
    shl     r13d, 3
    movzx   edi, byte [rsi + 1]         ; высота
    imul    eax, ebx, TX_SIZE
    lea     r12, [textures]
    add     r12, rax
    mov     [r12 + TX_WIDTH], r13d
    mov     [r12 + TX_HEIGHT], edi
    mov     eax, r13d
    dec     eax
    mov     [r12 + TX_WMASK], eax
    mov     eax, edi
    dec     eax
    mov     [r12 + TX_HMASK], eax
    mov     eax, edi
    shl     eax, 16
    mov     [r12 + TX_HFRAC], eax
    mov     ecx, r13d
    imul    ecx, edi
    add     ecx, 64
    call    Z_Malloc
    mov     [r12 + TX_DATA], rax
    inc     ebx
    cmp     ebx, NUMTEXTURES
    jb      .alloc

    ; --- генерация ---
    xor     ebx, ebx
.gen:
    imul    r12d, ebx, 8
    lea     rsi, [texdefs]
    add     rsi, r12
    movzx   eax, byte [rsi + 2]         ; тип узора
    mov     ecx, ebx                    ; номер текстуры
    movzx   edx, byte [rsi + 3]         ; базовый цвет
    movzx   r8d, byte [rsi + 4]         ; длина рампы
    movzx   r9d, byte [rsi + 5]         ; параметр
    lea     r10, [texgen_table]
    mov     r10, [r10 + rax*8]
    call    r10
    inc     ebx
    cmp     ebx, NUMTEXTURES
    jb      .gen

    ; --- флэты ---
    xor     ebx, ebx
.flatalloc:
    mov     ecx, 4096
    call    Z_Malloc
    lea     rdx, [flats]
    mov     [rdx + rbx*8], rax
    inc     ebx
    cmp     ebx, NUMFLATS
    jb      .flatalloc

    xor     ebx, ebx
.flatgen:
    imul    r12d, ebx, 4
    lea     rsi, [flatdefs]
    add     rsi, r12
    movzx   eax, byte [rsi + 0]
    mov     ecx, ebx
    movzx   edx, byte [rsi + 1]
    movzx   r8d, byte [rsi + 2]
    movzx   r9d, byte [rsi + 3]
    lea     r10, [flatgen_table]
    mov     r10, [r10 + rax*8]
    call    r10
    inc     ebx
    cmp     ebx, NUMFLATS
    jb      .flatgen

    ; таблицы подмены (анимация)
    xor     ebx, ebx
.trans:
    mov     [flattranslation + rbx*4], ebx
    inc     ebx
    cmp     ebx, NUMFLATS
    jb      .trans

    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_TexPut(ecx=texnum, edx=x, r8d=y, r9d=color)
; ---------------------------------------------------------------------------
R_TexPut:
    push    rbx
    imul    eax, ecx, TX_SIZE
    lea     rbx, [textures]
    add     rbx, rax
    mov     eax, [rbx + TX_WIDTH]
    cmp     edx, eax
    jae     .out
    mov     eax, [rbx + TX_HEIGHT]
    cmp     r8d, eax
    jae     .out
    imul    edx, eax
    add     edx, r8d
    mov     rax, [rbx + TX_DATA]
    mov     [rax + rdx], r9b
.out:
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  Генераторы текстур: ecx=texnum, edx=база цвета, r8d=длина рампы, r9d=параметр
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
;  Генераторы текстур: ecx=texnum, edx=база цвета, r8d=длина рампы, r9d=параметр
;
;  Общий приём: каждый блок/панель освещён сверху-слева -- светлая фаска по
;  верхнему и левому краю, тёмная по нижнему и правому, тёмный шов между
;  блоками. Плюс мелкое зерно, чтобы плоскость не выглядела пластиковой.
; ---------------------------------------------------------------------------

; TX_Begin(ecx=texnum, edx=база, r8d=рампа, r9d=параметр)
TX_Begin:
    mov     [tg_tex], ecx
    mov     [tg_base], edx
    mov     [tg_ramp], r8d
    mov     [tg_param], r9d
    imul    eax, ecx, TX_SIZE
    lea     rdx, [textures]
    add     rdx, rax
    mov     eax, [rdx + TX_WIDTH]
    mov     [tg_w], eax
    mov     eax, [rdx + TX_HEIGHT]
    mov     [tg_h], eax
    ret

; TX_Put(ecx=x, edx=y, r8d=оттенок 0..рампа-1)
TX_Put:
    mov     eax, r8d
    test    eax, eax
    jns     .p
    xor     eax, eax
.p:
    cmp     eax, [tg_ramp]
    jl      .ok
    mov     eax, [tg_ramp]
    dec     eax
.ok:
    add     eax, [tg_base]
    mov     r9d, eax
    mov     r8d, edx
    mov     edx, ecx
    mov     ecx, [tg_tex]
    jmp     R_TexPut

; TX_PutC(ecx=x, edx=y, r8d=абсолютный цвет)
TX_PutC:
    mov     r9d, r8d
    mov     r8d, edx
    mov     edx, ecx
    mov     ecx, [tg_tex]
    jmp     R_TexPut

; TX_Grain(ecx=x, edx=y) -> eax = 0..1, мелкое зерно
TX_Grain:
    call    R_Noise
    shr     eax, 7
    ret

; ---------------------------------------------------------------------------
;  TG_Brick -- кирпичная/блочная кладка со швами и фасками
;  параметр: 0 = кирпич 32x16, 1 = крупный блок 64x32
; ---------------------------------------------------------------------------
TG_Brick:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    call    TX_Begin
    mov     r14d, 32                    ; ширина блока
    mov     r15d, 16                    ; высота блока
    cmp     dword [tg_param], 0
    je      .sized
    mov     r14d, 64
    mov     r15d, 32
.sized:
    xor     edi, edi                    ; y
.yl:
    xor     esi, esi                    ; x
.xl:
    ; смещение нечётных рядов на половину блока
    mov     eax, edi
    xor     edx, edx
    div     r15d
    mov     r13d, eax                   ; номер ряда
    mov     ebx, esi
    test    r13d, 1
    jz      .noshift
    mov     eax, r14d
    shr     eax, 1
    add     ebx, eax
.noshift:
    mov     eax, ebx
    xor     edx, edx
    div     r14d
    mov     ebx, edx                    ; позиция внутри блока по X
    mov     eax, edi
    xor     edx, edx
    div     r15d
    mov     r12d, edx                   ; позиция внутри блока по Y

    ; --- шов ---
    cmp     r12d, 1
    jbe     .mortar
    cmp     ebx, 1
    jbe     .mortar

    ; --- тело кирпича: свой оттенок на блок ---
    mov     ecx, esi
    xor     edx, edx
    div     r14d                        ; edx уже занят -- пересчёт ниже
    mov     eax, esi
    xor     edx, edx
    div     r14d
    mov     ecx, eax                    ; колонка блока
    mov     edx, r13d
    call    R_Noise
    shr     eax, 6                      ; 0..3
    add     eax, 9                      ; базовый оттенок кирпича
    mov     r8d, eax
    ; фаски
    cmp     r12d, 2
    jne     .nb1
    sub     r8d, 3                      ; светлая кромка сверху
.nb1:
    mov     eax, r15d
    dec     eax
    cmp     r12d, eax
    jne     .nb2
    add     r8d, 4                      ; тень снизу
.nb2:
    cmp     ebx, 2
    jne     .nb3
    sub     r8d, 2
.nb3:
    mov     eax, r14d
    dec     eax
    cmp     ebx, eax
    jne     .nb4
    add     r8d, 3
.nb4:
    ; зерно
    push    r8
    mov     ecx, esi
    mov     edx, edi
    call    TX_Grain
    pop     r8
    add     r8d, eax
    jmp     .put
.mortar:
    mov     r8d, [tg_ramp]
    sub     r8d, 5
.put:
    mov     ecx, esi
    mov     edx, edi
    call    TX_Put
    inc     esi
    cmp     esi, [tg_w]
    jb      .xl
    inc     edi
    cmp     edi, [tg_h]
    jb      .yl
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  TG_Panel -- металлические панели с утопленными полями, фасками и заклёпками
;  параметр: 0 = обычная, 1 = светящаяся (яркие вставки)
; ---------------------------------------------------------------------------
TG_Panel:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    call    TX_Begin
    xor     edi, edi
.yl:
    xor     esi, esi
.xl:
    mov     ebx, esi
    and     ebx, 31                     ; позиция в панели по X
    mov     r12d, edi
    and     r12d, 31                    ; по Y
    mov     r13d, edi
    and     r13d, 63                    ; для горизонтальных поясов

    ; --- горизонтальный пояс на стыке панелей ---
    cmp     r13d, 2
    ja      .noband
    mov     r8d, [tg_ramp]
    sub     r8d, 3
    cmp     r13d, 0
    jne     .put
    mov     r8d, 6                      ; блик на верхней кромке пояса
    jmp     .put
.noband:

    ; --- рамка панели ---
    cmp     ebx, 0
    je      .seam
    cmp     r12d, 0
    je      .seam
    cmp     ebx, 1
    jbe     .hi
    cmp     r12d, 1
    jbe     .hi
    cmp     ebx, 30
    jae     .lo
    cmp     r12d, 30
    jae     .lo

    ; --- заклёпки по углам поля ---
    mov     eax, ebx
    sub     eax, 5
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    mov     r14d, eax                   ; |x-5|
    mov     eax, ebx
    sub     eax, 26
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    cmp     eax, r14d
    jge     .rx
    mov     r14d, eax
.rx:
    mov     eax, r12d
    sub     eax, 5
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    mov     r15d, eax
    mov     eax, r12d
    sub     eax, 26
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    cmp     eax, r15d
    jge     .ry
    mov     r15d, eax
.ry:
    add     r14d, r15d
    cmp     r14d, 2
    ja      .field
    mov     r8d, 7                      ; заклёпка
    cmp     r14d, 2
    jne     .put
    mov     r8d, [tg_ramp]
    sub     r8d, 5                      ; тень под заклёпкой
    jmp     .put

.field:
    ; утопленное поле с зерном
    mov     ecx, esi
    mov     edx, edi
    call    TX_Grain
    add     eax, 13
    mov     r8d, eax
    cmp     dword [tg_param], 0
    je      .put
    sub     r8d, 7                      ; светящаяся панель
    jmp     .put
.seam:
    mov     r8d, [tg_ramp]
    sub     r8d, 2
    jmp     .put
.hi:
    mov     r8d, 7
    jmp     .put
.lo:
    mov     r8d, [tg_ramp]
    sub     r8d, 9
.put:
    mov     ecx, esi
    mov     edx, edi
    call    TX_Put
    inc     esi
    cmp     esi, [tg_w]
    jb      .xl
    inc     edi
    cmp     edi, [tg_h]
    jb      .yl
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  TG_Door -- створка: рамка, горизонтальные рёбра, центральный шов
;  параметр: 0 = обычная, иначе база цвета ключевой полосы
; ---------------------------------------------------------------------------
TG_Door:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    call    TX_Begin
    mov     r14d, [tg_w]
    shr     r14d, 1                     ; центр
    xor     edi, edi
.yl:
    xor     esi, esi
.xl:
    ; расстояние от центрального шва
    mov     eax, esi
    sub     eax, r14d
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    mov     ebx, eax
    ; расстояние до ближайшего края
    mov     r12d, esi
    mov     eax, [tg_w]
    dec     eax
    sub     eax, esi
    cmp     eax, r12d
    jge     .edge
    mov     r12d, eax
.edge:
    mov     r13d, edi
    and     r13d, 15                    ; позиция в ребре

    ; --- боковая рама ---
    cmp     r12d, 3
    ja      .noframe
    mov     r8d, [tg_ramp]
    sub     r8d, 3
    cmp     r12d, 3
    jne     .put
    mov     r8d, 7                      ; блик на внутренней кромке рамы
    jmp     .put
.noframe:
    ; --- центральный шов ---
    cmp     ebx, 1
    ja      .noseam
    mov     r8d, [tg_ramp]
    sub     r8d, 2
    jmp     .put
.noseam:
    ; --- горизонтальные рёбра ---
    cmp     r13d, 1
    ja      .norib
    mov     r8d, 7                      ; светлая кромка ребра
    jmp     .grain
.norib:
    cmp     r13d, 14
    jb      .flat
    mov     r8d, [tg_ramp]
    sub     r8d, 7                      ; тень под ребром
    jmp     .grain
.flat:
    mov     r8d, 12
.grain:
    push    r8
    mov     ecx, esi
    mov     edx, edi
    call    TX_Grain
    pop     r8
    add     r8d, eax

    ; --- цветная полоса ключа ---
    cmp     dword [tg_param], 0
    je      .put
    mov     eax, [tg_h]
    shr     eax, 1
    mov     ecx, edi
    sub     ecx, eax
    mov     eax, ecx
    sar     eax, 31
    xor     ecx, eax
    sub     ecx, eax
    cmp     ecx, 10
    ja      .put
    cmp     ebx, 4
    jb      .put
    cmp     ebx, 20
    ja      .put
    mov     r8d, [tg_param]
    add     r8d, 2
    shr     ecx, 2
    add     r8d, ecx
    mov     ecx, esi
    mov     edx, edi
    call    TX_PutC
    jmp     .next
.put:
    mov     ecx, esi
    mov     edx, edi
    call    TX_Put
.next:
    inc     esi
    cmp     esi, [tg_w]
    jb      .xl
    inc     edi
    cmp     edi, [tg_h]
    jb      .yl
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  TG_Noise -- камень/мрамор: крупные пятна, прожилки, зерно
; ---------------------------------------------------------------------------
TG_Noise:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    call    TX_Begin
    xor     edi, edi
.yl:
    xor     esi, esi
.xl:
    ; крупные пятна
    mov     ecx, esi
    shr     ecx, 3
    mov     edx, edi
    shr     edx, 3
    call    R_Noise
    imul    eax, 3
    mov     r12d, eax
    ; средние
    mov     ecx, esi
    shr     ecx, 1
    mov     edx, edi
    shr     edx, 1
    call    R_Noise
    add     eax, r12d
    shr     eax, 2                      ; 0..255
    mov     r12d, eax
    ; прожилка: тонкая тёмная линия там, где шум около порога
    mov     ecx, esi
    shr     ecx, 1
    mov     edx, edi
    shr     edx, 2
    call    R_Noise
    sub     eax, 128
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    cmp     eax, 6
    ja      .novein
    mov     r8d, [tg_ramp]
    sub     r8d, 3
    jmp     .put
.novein:
    mov     eax, r12d
    mov     ecx, [tg_ramp]
    imul    ecx, 3
    shr     ecx, 2
    imul    eax, ecx
    shr     eax, 8
    mov     ecx, [tg_ramp]
    shr     ecx, 3
    add     eax, ecx
    mov     r8d, eax
.put:
    mov     ecx, esi
    mov     edx, edi
    call    TX_Put
    inc     esi
    cmp     esi, [tg_w]
    jb      .xl
    inc     edi
    cmp     edi, [tg_h]
    jb      .yl
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  TG_Comp -- компьютерная панель: корпус, экран со строками, индикаторы
; ---------------------------------------------------------------------------
TG_Comp:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    call    TX_Begin
    xor     edi, edi
.yl:
    xor     esi, esi
.xl:
    mov     ebx, esi
    and     ebx, 31
    mov     r12d, edi
    and     r12d, 63

    ; --- корпус ---
    cmp     r12d, 6
    jb      .body
    cmp     r12d, 44
    ja      .body
    cmp     ebx, 3
    jb      .body
    cmp     ebx, 28
    ja      .body
    ; --- экран ---
    cmp     r12d, 7
    je      .screenedge
    cmp     ebx, 4
    je      .screenedge
    ; строки данных
    mov     ecx, esi
    shr     ecx, 1
    mov     edx, edi
    shr     edx, 1
    call    R_Noise
    cmp     eax, 150
    jb      .darkscreen
    mov     r8d, PAL_GREEN + 2
    mov     ecx, esi
    mov     edx, edi
    call    TX_PutC
    jmp     .next
.darkscreen:
    mov     r8d, PAL_GREEN + 24
    mov     ecx, esi
    mov     edx, edi
    call    TX_PutC
    jmp     .next
.screenedge:
    mov     r8d, [tg_ramp]
    sub     r8d, 2
    jmp     .put
.body:
    ; индикаторы вдоль нижнего края блока
    cmp     r12d, 50
    jb      .nolamp
    cmp     r12d, 54
    ja      .nolamp
    mov     eax, ebx
    and     eax, 7
    cmp     eax, 3
    ja      .nolamp
    mov     ecx, esi
    shr     ecx, 3
    mov     edx, 1
    call    R_Noise
    mov     r8d, PAL_RED + 2
    cmp     eax, 128
    jb      .lampput
    mov     r8d, PAL_YELLOW + 2
.lampput:
    mov     ecx, esi
    mov     edx, edi
    call    TX_PutC
    jmp     .next
.nolamp:
    mov     ecx, esi
    mov     edx, edi
    call    TX_Grain
    add     eax, 16
    mov     r8d, eax
    ; фаска корпуса
    cmp     r12d, 0
    jne     .nc1
    mov     r8d, 7
.nc1:
    cmp     r12d, 63
    jne     .nc2
    mov     r8d, [tg_ramp]
    sub     r8d, 5
.nc2:
.put:
    mov     ecx, esi
    mov     edx, edi
    call    TX_Put
.next:
    inc     esi
    cmp     esi, [tg_w]
    jb      .xl
    inc     edi
    cmp     edi, [tg_h]
    jb      .yl
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  TG_Switch -- панель + утопленный корпус рубильника с лампой
;  параметр: 0 = выключен (красная), 1 = включён (зелёная)
; ---------------------------------------------------------------------------
TG_Switch:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    ; сначала обычная панель
    push    r9
    xor     r9d, r9d
    call    TG_Panel
    pop     r9
    mov     r15d, r9d
    mov     eax, [tg_w]
    shr     eax, 1
    mov     r13d, eax                   ; центр X
    mov     eax, [tg_h]
    shr     eax, 1
    mov     r14d, eax                   ; центр Y
    mov     edi, -14
.yl:
    mov     esi, -10
.xl:
    ; расстояния от центра
    mov     eax, esi
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    mov     ebx, eax                    ; |dx|
    mov     eax, edi
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    mov     r12d, eax                   ; |dy|

    cmp     ebx, 9
    ja      .next
    cmp     r12d, 13
    ja      .next
    ; корпус с фаской
    mov     r8d, PAL_GRAY + 14
    cmp     r12d, 13
    je      .draw
    cmp     ebx, 9
    je      .draw
    mov     r8d, PAL_GRAY + 6
    cmp     edi, -13
    jle     .draw                       ; светлая кромка сверху
    mov     r8d, PAL_GRAY + 20
    cmp     edi, 12
    jge     .draw                       ; тень снизу
    mov     r8d, PAL_GRAY + 10
    ; лампа в центре
    cmp     ebx, 5
    ja      .draw
    cmp     r12d, 7
    ja      .draw
    mov     r8d, PAL_RED + 2
    test    r15d, r15d
    jz      .lamp
    mov     r8d, PAL_GREEN + 2
.lamp:
    ; блик в верхней части лампы
    cmp     edi, -3
    jg      .draw
    sub     r8d, 1
.draw:
    lea     ecx, [r13d + esi]
    lea     edx, [r14d + edi]
    push    rsi
    push    rdi
    call    TX_PutC
    pop     rdi
    pop     rsi
.next:
    inc     esi
    cmp     esi, 10
    jle     .xl
    inc     edi
    cmp     edi, 14
    jle     .yl
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  TG_Step -- ступень: горизонтальные металлические полосы
; ---------------------------------------------------------------------------
TG_Step:
    push    rbx
    push    rsi
    push    rdi
    call    TX_Begin
    xor     edi, edi
.yl:
    xor     esi, esi
.xl:
    mov     ebx, edi
    and     ebx, 7
    mov     r8d, 11
    cmp     ebx, 0
    jne     .n1
    mov     r8d, 6                      ; блик
.n1:
    cmp     ebx, 6
    jb      .n2
    mov     r8d, [tg_ramp]
    sub     r8d, 5                      ; тень
.n2:
    push    r8
    mov     ecx, esi
    mov     edx, edi
    call    TX_Grain
    pop     r8
    add     r8d, eax
    mov     ecx, esi
    mov     edx, edi
    call    TX_Put
    inc     esi
    cmp     esi, [tg_w]
    jb      .xl
    inc     edi
    cmp     edi, [tg_h]
    jb      .yl
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  TG_Sky -- градиент неба, облачные полосы и зубчатый горизонт
; ---------------------------------------------------------------------------
TG_Sky:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    call    TX_Begin
    xor     edi, edi
.yl:
    xor     esi, esi
.xl:
    ; градиент: вверху темнее, к горизонту светлее
    mov     eax, edi
    imul    eax, 18
    shr     eax, 7
    mov     r13d, PAL_BLUE + 14
    sub     r13d, eax
    ; облачные разводы
    mov     ecx, esi
    shr     ecx, 2
    mov     edx, edi
    shr     edx, 1
    call    R_Noise
    cmp     eax, 170
    jb      .nocloud
    sub     r13d, 2
.nocloud:
    ; горизонт с зубцами
    mov     ecx, esi
    shr     ecx, 2
    mov     edx, 7
    call    R_Noise
    shr     eax, 3
    add     eax, 78
    mov     r12d, eax
    cmp     edi, r12d
    jb      .putsky
    ; скалы
    mov     r13d, PAL_GRAY + 20
    mov     ecx, esi
    mov     edx, edi
    call    R_Noise
    shr     eax, 6
    add     r13d, eax
    ; кромка гребня светлее
    mov     eax, r12d
    inc     eax
    cmp     edi, eax
    jg      .putsky
    mov     r13d, PAL_GRAY + 12
.putsky:
    mov     ecx, esi
    mov     edx, edi
    mov     r8d, r13d
    call    TX_PutC
    inc     esi
    cmp     esi, [tg_w]
    jb      .xl
    inc     edi
    cmp     edi, [tg_h]
    jb      .yl
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ===========================================================================
;  Флэты 64x64
; ===========================================================================

; FG_Tile: плитка со швами и фаской
FG_Tile:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    mov     r12d, ecx
    mov     r13d, edx
    mov     r14d, r8d
    lea     rbx, [flats]
    mov     rbx, [rbx + r12*8]
    xor     edi, edi
.yl:
    xor     esi, esi
.xl:
    mov     ecx, esi
    and     ecx, 31
    mov     edx, edi
    and     edx, 31
    cmp     ecx, 0
    je      .seam
    cmp     edx, 0
    je      .seam
    cmp     ecx, 1
    je      .hi
    cmp     edx, 1
    je      .hi
    cmp     ecx, 31
    je      .lo
    cmp     edx, 31
    je      .lo
    mov     ecx, esi
    mov     edx, edi
    call    R_Noise
    shr     eax, 7
    add     eax, 12
    jmp     .put
.seam:
    mov     eax, r14d
    sub     eax, 3
    jmp     .put
.hi:
    mov     eax, 7
    jmp     .put
.lo:
    mov     eax, r14d
    sub     eax, 8
.put:
    test    eax, eax
    jns     .p1
    xor     eax, eax
.p1:
    cmp     eax, r14d
    jl      .p2
    mov     eax, r14d
    dec     eax
.p2:
    add     eax, r13d
    mov     ecx, edi
    shl     ecx, 6
    add     ecx, esi
    mov     [rbx + rcx], al
    inc     esi
    cmp     esi, 64
    jb      .xl
    inc     edi
    cmp     edi, 64
    jb      .yl
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; FG_Noise: органический флэт (земля, кислота, кровь); r9d = фаза анимации
FG_Noise:
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
    lea     rbx, [flats]
    mov     rbx, [rbx + r12*8]
    xor     edi, edi
.yl:
    xor     esi, esi
.xl:
    ; крупная структура со сдвигом по фазе -- получается «течение»
    mov     ecx, esi
    add     ecx, r15d
    shr     ecx, 3
    mov     edx, edi
    sub     edx, r15d
    shr     edx, 3
    call    R_Noise
    imul    eax, 3
    push    rax
    mov     ecx, esi
    shr     ecx, 1
    mov     edx, edi
    shr     edx, 1
    call    R_Noise
    pop     rdx
    add     eax, edx
    shr     eax, 2
    imul    eax, r14d
    shr     eax, 8
    add     eax, r13d
    mov     ecx, edi
    shl     ecx, 6
    add     ecx, esi
    mov     [rbx + rcx], al
    inc     esi
    cmp     esi, 64
    jb      .xl
    inc     edi
    cmp     edi, 64
    jb      .yl
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; FG_Grate: решётка с фаской и тёмными отверстиями
FG_Grate:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    mov     r12d, ecx
    mov     r13d, edx
    mov     r14d, r8d
    lea     rbx, [flats]
    mov     rbx, [rbx + r12*8]
    xor     edi, edi
.yl:
    xor     esi, esi
.xl:
    mov     ecx, esi
    and     ecx, 15
    mov     edx, edi
    and     edx, 15
    mov     eax, 10
    cmp     ecx, 3
    jb      .frame
    cmp     ecx, 12
    ja      .frame
    cmp     edx, 3
    jb      .frame
    cmp     edx, 12
    ja      .frame
    ; отверстие
    mov     eax, r14d
    dec     eax
    cmp     ecx, 4
    jne     .put
    mov     eax, r14d
    sub     eax, 5
    jmp     .put
.frame:
    cmp     ecx, 0
    je      .hi
    cmp     edx, 0
    je      .hi
    cmp     ecx, 15
    je      .lo
    cmp     edx, 15
    je      .lo
    mov     eax, 10
    jmp     .put
.hi:
    mov     eax, 6
    jmp     .put
.lo:
    mov     eax, r14d
    sub     eax, 6
.put:
    test    eax, eax
    jns     .p1
    xor     eax, eax
.p1:
    cmp     eax, r14d
    jl      .p2
    mov     eax, r14d
    dec     eax
.p2:
    add     eax, r13d
    mov     ecx, edi
    shl     ecx, 6
    add     ecx, esi
    mov     [rbx + rcx], al
    inc     esi
    cmp     esi, 64
    jb      .xl
    inc     edi
    cmp     edi, 64
    jb      .yl
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ===========================================================================
;  Доступ к текстурам
; ===========================================================================

; R_GetColumn(ecx=texnum, edx=col) -> rax
R_GetColumn:
    imul    eax, ecx, TX_SIZE
    lea     r8, [textures]
    add     r8, rax
    and     edx, [r8 + TX_WMASK]
    imul    edx, [r8 + TX_HEIGHT]
    mov     rax, [r8 + TX_DATA]
    add     rax, rdx
    ret

; R_TexHeightMask(ecx=texnum) -> eax
R_TexHeightMask:
    imul    eax, ecx, TX_SIZE
    lea     r8, [textures]
    add     r8, rax
    mov     eax, [r8 + TX_HMASK]
    ret

; R_TexHeightFrac(ecx=texnum) -> eax
R_TexHeightFrac:
    imul    eax, ecx, TX_SIZE
    lea     r8, [textures]
    add     r8, rax
    mov     eax, [r8 + TX_HFRAC]
    ret

; R_GetFlat(ecx=flatnum) -> rax
R_GetFlat:
    mov     eax, [flattranslation + rcx*4]
    lea     r8, [flats]
    mov     rax, [r8 + rax*8]
    ret
