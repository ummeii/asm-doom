; ===========================================================================
;  p_setup.asm -- загрузка уровня из потока записей, сборка линий/сторон,
;                 blockmap, списки линий секторов, сетка поиска сектора
;
;  Поток уровня (массив dd):
;     3, x, y                                             -- вершина
;     1, floorh, ceilh, floorpic, ceilpic, light, spec, tag -- сектор
;     2, v1, v2, upper, mid, lower, xoff, yoff, flags, spec, tag -- стена
;     4, x, y, angle, type, flags                          -- объект
;     0                                                    -- конец
;
;  Вершины сектора перечисляются по часовой стрелке (ось Y вверх), поэтому
;  сектор всегда оказывается с "правой" стороны стены -- это лицевая сторона.
; ===========================================================================

%define WD_V1       0
%define WD_V2       4
%define WD_UPPER    8
%define WD_MID      12
%define WD_LOWER    16
%define WD_XOFF     20
%define WD_YOFF     24
%define WD_FLAGS    28
%define WD_SPECIAL  32
%define WD_TAG      36
%define WD_SECTOR   40
%define WD_PAIRED   44
%define WALLDEF_SIZE 48

%define TH_X        0
%define TH_Y        4
%define TH_ANGLE    8
%define TH_TYPE     12
%define TH_FLAGS    16
%define THINGDEF_SIZE 20

%define MAPBLOCKUNITS   128
%define MAPBLOCKSIZE    (128*FRACUNIT)
%define MAPBLOCKSHIFT   (FRACBITS+7)
%define MAPBTOFRAC      (MAPBLOCKSHIFT-FRACBITS)

; ---------------------------------------------------------------------------
;  P_SetupLevel(rcx = указатель на поток уровня)
; ---------------------------------------------------------------------------
P_SetupLevel:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15

    mov     rsi, rcx
    mov     dword [numvertexes], 0
    mov     dword [numsectors], 0
    mov     dword [numwalldefs], 0
    mov     dword [numthings], 0
    mov     dword [numlines], 0
    mov     dword [numsides], 0
    mov     dword [cursector], -1

; --------------------------- разбор потока ---------------------------------
.parse:
    mov     eax, [rsi]
    cmp     eax, 0
    je      .parsedone
    cmp     eax, 3
    je      .rvertex
    cmp     eax, 1
    je      .rsector
    cmp     eax, 2
    je      .rwall
    cmp     eax, 4
    je      .rthing
    mov     rcx, str_err_map
    call    I_Error

.rvertex:
    mov     eax, [numvertexes]
    imul    ebx, eax, VERTEX_SIZE
    mov     ecx, [rsi + 4]
    shl     ecx, 16
    mov     [vertexes + rbx + VX_X], ecx
    mov     ecx, [rsi + 8]
    shl     ecx, 16
    mov     [vertexes + rbx + VX_Y], ecx
    inc     dword [numvertexes]
    add     rsi, 12
    jmp     .parse

.rsector:
    mov     eax, [numsectors]
    imul    ebx, eax, SECTOR_SIZE
    mov     ecx, [rsi + 4]
    shl     ecx, 16
    mov     [sectors + rbx + SEC_FLOORH], ecx
    mov     ecx, [rsi + 8]
    shl     ecx, 16
    mov     [sectors + rbx + SEC_CEILH], ecx
    mov     ecx, [rsi + 12]
    mov     [sectors + rbx + SEC_FLOORPIC], ecx
    mov     ecx, [rsi + 16]
    mov     [sectors + rbx + SEC_CEILPIC], ecx
    mov     ecx, [rsi + 20]
    mov     [sectors + rbx + SEC_LIGHT], ecx
    mov     [sectors + rbx + SEC_LIGHTBASE], ecx
    mov     ecx, [rsi + 24]
    mov     [sectors + rbx + SEC_SPECIAL], ecx
    mov     ecx, [rsi + 28]
    mov     [sectors + rbx + SEC_TAG], ecx
    mov     qword [sectors + rbx + SEC_THINGLIST], 0
    mov     qword [sectors + rbx + SEC_SPECIALDATA], 0
    mov     qword [sectors + rbx + SEC_SOUNDTARGET], 0
    mov     dword [sectors + rbx + SEC_VALIDCOUNT], 0
    mov     dword [sectors + rbx + SEC_LINECOUNT], 0
    mov     eax, [numsectors]
    mov     [cursector], eax
    inc     dword [numsectors]
    add     rsi, 32
    jmp     .parse

.rwall:
    mov     eax, [numwalldefs]
    imul    ebx, eax, WALLDEF_SIZE
    mov     ecx, [rsi + 4]
    mov     [walldefs + rbx + WD_V1], ecx
    mov     ecx, [rsi + 8]
    mov     [walldefs + rbx + WD_V2], ecx
    mov     ecx, [rsi + 12]
    mov     [walldefs + rbx + WD_UPPER], ecx
    mov     ecx, [rsi + 16]
    mov     [walldefs + rbx + WD_MID], ecx
    mov     ecx, [rsi + 20]
    mov     [walldefs + rbx + WD_LOWER], ecx
    mov     ecx, [rsi + 24]
    mov     [walldefs + rbx + WD_XOFF], ecx
    mov     ecx, [rsi + 28]
    mov     [walldefs + rbx + WD_YOFF], ecx
    mov     ecx, [rsi + 32]
    mov     [walldefs + rbx + WD_FLAGS], ecx
    mov     ecx, [rsi + 36]
    mov     [walldefs + rbx + WD_SPECIAL], ecx
    mov     ecx, [rsi + 40]
    mov     [walldefs + rbx + WD_TAG], ecx
    mov     ecx, [cursector]
    mov     [walldefs + rbx + WD_SECTOR], ecx
    mov     dword [walldefs + rbx + WD_PAIRED], 0
    inc     dword [numwalldefs]
    add     rsi, 44
    jmp     .parse

.rthing:
    mov     eax, [numthings]
    imul    ebx, eax, THINGDEF_SIZE
    mov     ecx, [rsi + 4]
    mov     [thingdefs + rbx + TH_X], ecx
    mov     ecx, [rsi + 8]
    mov     [thingdefs + rbx + TH_Y], ecx
    mov     ecx, [rsi + 12]
    mov     [thingdefs + rbx + TH_ANGLE], ecx
    mov     ecx, [rsi + 16]
    mov     [thingdefs + rbx + TH_TYPE], ecx
    mov     ecx, [rsi + 20]
    mov     [thingdefs + rbx + TH_FLAGS], ecx
    inc     dword [numthings]
    add     rsi, 24
    jmp     .parse

.parsedone:

; --------------------------- сборка линий ----------------------------------
    xor     r12d, r12d                  ; i
.pairloop:
    cmp     r12d, [numwalldefs]
    jae     .pairdone
    imul    r13d, r12d, WALLDEF_SIZE    ; смещение стены i
    cmp     dword [walldefs + r13 + WD_PAIRED], 0
    jne     .pairnext

    ; ищем обратную стену (v2,v1)
    mov     r14d, -1                    ; индекс парной стены
    mov     eax, [walldefs + r13 + WD_V1]
    mov     r8d, [walldefs + r13 + WD_V2]
    xor     r15d, r15d
.findloop:
    cmp     r15d, [numwalldefs]
    jae     .findend
    cmp     r15d, r12d
    je      .findnext
    imul    ecx, r15d, WALLDEF_SIZE
    cmp     dword [walldefs + rcx + WD_PAIRED], 0
    jne     .findnext
    cmp     [walldefs + rcx + WD_V1], r8d
    jne     .findnext
    cmp     [walldefs + rcx + WD_V2], eax
    jne     .findnext
    mov     r14d, r15d
    jmp     .findend
.findnext:
    inc     r15d
    jmp     .findloop
.findend:

    ; --- сторона 0 ---
    mov     eax, [numsides]
    imul    ebx, eax, SIDE_SIZE
    mov     ecx, [walldefs + r13 + WD_XOFF]
    shl     ecx, 16
    mov     [sides + rbx + SD_TEXOFF], ecx
    mov     ecx, [walldefs + r13 + WD_YOFF]
    shl     ecx, 16
    mov     [sides + rbx + SD_ROWOFF], ecx
    mov     ecx, [walldefs + r13 + WD_UPPER]
    mov     [sides + rbx + SD_TOPTEX], ecx
    mov     ecx, [walldefs + r13 + WD_LOWER]
    mov     [sides + rbx + SD_BOTTEX], ecx
    mov     ecx, [walldefs + r13 + WD_MID]
    mov     [sides + rbx + SD_MIDTEX], ecx
    mov     ecx, [walldefs + r13 + WD_SECTOR]
    mov     [sides + rbx + SD_SECTOR], ecx
    mov     r10d, [numsides]            ; индекс стороны 0
    inc     dword [numsides]

    mov     r11d, -1                    ; индекс стороны 1
    cmp     r14d, -1
    je      .noside1
    imul    r15d, r14d, WALLDEF_SIZE
    mov     eax, [numsides]
    imul    ebx, eax, SIDE_SIZE
    mov     ecx, [walldefs + r15 + WD_XOFF]
    shl     ecx, 16
    mov     [sides + rbx + SD_TEXOFF], ecx
    mov     ecx, [walldefs + r15 + WD_YOFF]
    shl     ecx, 16
    mov     [sides + rbx + SD_ROWOFF], ecx
    mov     ecx, [walldefs + r15 + WD_UPPER]
    mov     [sides + rbx + SD_TOPTEX], ecx
    mov     ecx, [walldefs + r15 + WD_LOWER]
    mov     [sides + rbx + SD_BOTTEX], ecx
    mov     ecx, [walldefs + r15 + WD_MID]
    mov     [sides + rbx + SD_MIDTEX], ecx
    mov     ecx, [walldefs + r15 + WD_SECTOR]
    mov     [sides + rbx + SD_SECTOR], ecx
    mov     r11d, [numsides]
    inc     dword [numsides]
    mov     dword [walldefs + r15 + WD_PAIRED], 1
.noside1:
    mov     dword [walldefs + r13 + WD_PAIRED], 1

    ; --- линия ---
    mov     eax, [numlines]
    imul    ebx, eax, LINE_SIZE
    mov     ecx, [walldefs + r13 + WD_V1]
    mov     [lines + rbx + LN_V1], ecx
    mov     ecx, [walldefs + r13 + WD_V2]
    mov     [lines + rbx + LN_V2], ecx
    mov     [lines + rbx + LN_SIDE0], r10d
    mov     [lines + rbx + LN_SIDE1], r11d
    mov     ecx, [walldefs + r13 + WD_SECTOR]
    mov     [lines + rbx + LN_FRONTSEC], ecx
    mov     dword [lines + rbx + LN_BACKSEC], -1
    mov     ecx, [walldefs + r13 + WD_FLAGS]
    mov     edx, [walldefs + r13 + WD_SPECIAL]
    mov     r8d, [walldefs + r13 + WD_TAG]
    cmp     r14d, -1
    je      .oneside
    or      ecx, ML_TWOSIDED
    imul    r15d, r14d, WALLDEF_SIZE
    or      ecx, [walldefs + r15 + WD_FLAGS]
    mov     r9d, [walldefs + r15 + WD_SECTOR]
    mov     [lines + rbx + LN_BACKSEC], r9d
    test    edx, edx
    jnz     .havespec
    mov     edx, [walldefs + r15 + WD_SPECIAL]
    mov     r8d, [walldefs + r15 + WD_TAG]
.havespec:
.oneside:
    mov     [lines + rbx + LN_FLAGS], ecx
    mov     [lines + rbx + LN_SPECIAL], edx
    mov     [lines + rbx + LN_TAG], r8d
    mov     dword [lines + rbx + LN_VALID], 0
    inc     dword [numlines]

.pairnext:
    inc     r12d
    jmp     .pairloop
.pairdone:

; --------------------------- геометрия линий -------------------------------
    xor     ebx, ebx
.geoloop:
    cmp     ebx, [numlines]
    jae     .geodone
    imul    r12d, ebx, LINE_SIZE
    mov     eax, [lines + r12 + LN_V1]
    imul    eax, VERTEX_SIZE
    mov     r8d, [vertexes + rax + VX_X]        ; x1
    mov     r9d, [vertexes + rax + VX_Y]        ; y1
    mov     eax, [lines + r12 + LN_V2]
    imul    eax, VERTEX_SIZE
    mov     r10d, [vertexes + rax + VX_X]       ; x2
    mov     r11d, [vertexes + rax + VX_Y]       ; y2
    mov     ecx, r10d
    sub     ecx, r8d
    mov     [lines + r12 + LN_DX], ecx
    mov     edx, r11d
    sub     edx, r9d
    mov     [lines + r12 + LN_DY], edx
    ; slopetype
    test    ecx, ecx
    jnz     .notvert
    mov     dword [lines + r12 + LN_SLOPETYPE], ST_VERTICAL
    jmp     .slopedone
.notvert:
    test    edx, edx
    jnz     .nothoriz
    mov     dword [lines + r12 + LN_SLOPETYPE], ST_HORIZONTAL
    jmp     .slopedone
.nothoriz:
    mov     eax, ecx
    xor     eax, edx
    mov     r13d, ST_POSITIVE
    test    eax, eax
    jns     .slp
    mov     r13d, ST_NEGATIVE
.slp:
    mov     [lines + r12 + LN_SLOPETYPE], r13d
.slopedone:
    ; bbox
    mov     eax, r8d
    mov     ecx, r10d
    cmp     eax, ecx
    jle     .xok
    xchg    eax, ecx
.xok:
    mov     [lines + r12 + LN_BBOXLEFT], eax
    mov     [lines + r12 + LN_BBOXRIGHT], ecx
    mov     eax, r9d
    mov     ecx, r11d
    cmp     eax, ecx
    jle     .yok
    xchg    eax, ecx
.yok:
    mov     [lines + r12 + LN_BBOXBOT], eax
    mov     [lines + r12 + LN_BBOXTOP], ecx
    inc     ebx
    jmp     .geoloop
.geodone:

    call    P_GroupSectorLines
    call    P_InitBlockmap
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_GroupSectorLines -- списки линий по секторам + bbox сектора
; ---------------------------------------------------------------------------
P_GroupSectorLines:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13

    ; счётчики
    xor     ebx, ebx
.clr:
    cmp     ebx, [numsectors]
    jae     .clrdone
    imul    r12d, ebx, SECTOR_SIZE
    mov     dword [sectors + r12 + SEC_LINECOUNT], 0
    mov     dword [sectors + r12 + SEC_BBOXLEFT], MAXINT
    mov     dword [sectors + r12 + SEC_BBOXBOT], MAXINT
    mov     dword [sectors + r12 + SEC_BBOXRIGHT], MININT
    mov     dword [sectors + r12 + SEC_BBOXTOP], MININT
    inc     ebx
    jmp     .clr
.clrdone:

    ; подсчёт
    xor     ebx, ebx
.cnt:
    cmp     ebx, [numlines]
    jae     .cntdone
    imul    r12d, ebx, LINE_SIZE
    mov     eax, [lines + r12 + LN_FRONTSEC]
    cmp     eax, -1
    je      .cnt2
    imul    eax, SECTOR_SIZE
    inc     dword [sectors + rax + SEC_LINECOUNT]
.cnt2:
    mov     eax, [lines + r12 + LN_BACKSEC]
    cmp     eax, -1
    je      .cntnext
    imul    eax, SECTOR_SIZE
    inc     dword [sectors + rax + SEC_LINECOUNT]
.cntnext:
    inc     ebx
    jmp     .cnt
.cntdone:

    ; выделение памяти под списки
    xor     ebx, ebx
    xor     r13d, r13d                  ; текущее смещение в общем массиве
.alloc:
    cmp     ebx, [numsectors]
    jae     .allocdone
    imul    r12d, ebx, SECTOR_SIZE
    mov     eax, r13d
    imul    eax, 4
    lea     rax, [seclinebuf + rax]
    mov     [sectors + r12 + SEC_LINES], rax
    add     r13d, [sectors + r12 + SEC_LINECOUNT]
    mov     dword [sectors + r12 + SEC_LINECOUNT], 0
    inc     ebx
    jmp     .alloc
.allocdone:

    ; заполнение
    xor     ebx, ebx
.fill:
    cmp     ebx, [numlines]
    jae     .filldone
    imul    r12d, ebx, LINE_SIZE
    mov     eax, [lines + r12 + LN_FRONTSEC]
    cmp     eax, -1
    je      .fill2
    call    P_AddLineToSector
.fill2:
    mov     eax, [lines + r12 + LN_BACKSEC]
    cmp     eax, -1
    je      .fillnext
    call    P_AddLineToSector
.fillnext:
    inc     ebx
    jmp     .fill
.filldone:

    ; центр звука
    xor     ebx, ebx
.org:
    cmp     ebx, [numsectors]
    jae     .orgdone
    imul    r12d, ebx, SECTOR_SIZE
    mov     eax, [sectors + r12 + SEC_BBOXLEFT]
    mov     ecx, [sectors + r12 + SEC_BBOXRIGHT]
    add     eax, ecx
    sar     eax, 1
    mov     [sectors + r12 + SEC_ORGX], eax
    mov     eax, [sectors + r12 + SEC_BBOXBOT]
    mov     ecx, [sectors + r12 + SEC_BBOXTOP]
    add     eax, ecx
    sar     eax, 1
    mov     [sectors + r12 + SEC_ORGY], eax
    inc     ebx
    jmp     .org
.orgdone:

    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; eax = индекс сектора, ebx = индекс линии, r12d = смещение линии
P_AddLineToSector:
    push    rcx
    push    rdx
    push    r8
    push    r9
    imul    eax, SECTOR_SIZE
    mov     r8d, [sectors + rax + SEC_LINECOUNT]
    mov     r9, [sectors + rax + SEC_LINES]
    mov     [r9 + r8*4], ebx
    inc     dword [sectors + rax + SEC_LINECOUNT]
    ; расширяем bbox
    mov     ecx, [lines + r12 + LN_BBOXLEFT]
    cmp     ecx, [sectors + rax + SEC_BBOXLEFT]
    jge     .l1
    mov     [sectors + rax + SEC_BBOXLEFT], ecx
.l1:
    mov     ecx, [lines + r12 + LN_BBOXRIGHT]
    cmp     ecx, [sectors + rax + SEC_BBOXRIGHT]
    jle     .l2
    mov     [sectors + rax + SEC_BBOXRIGHT], ecx
.l2:
    mov     ecx, [lines + r12 + LN_BBOXBOT]
    cmp     ecx, [sectors + rax + SEC_BBOXBOT]
    jge     .l3
    mov     [sectors + rax + SEC_BBOXBOT], ecx
.l3:
    mov     ecx, [lines + r12 + LN_BBOXTOP]
    cmp     ecx, [sectors + rax + SEC_BBOXTOP]
    jle     .l4
    mov     [sectors + rax + SEC_BBOXTOP], ecx
.l4:
    pop     r9
    pop     r8
    pop     rdx
    pop     rcx
    ret

; ---------------------------------------------------------------------------
;  P_InitBlockmap -- сетка 128x128 единиц: списки линий и объектов
; ---------------------------------------------------------------------------
P_InitBlockmap:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15

    ; --- границы карты ---
    mov     r8d, MAXINT                 ; minx
    mov     r9d, MAXINT                 ; miny
    mov     r10d, MININT                ; maxx
    mov     r11d, MININT                ; maxy
    xor     ebx, ebx
.bounds:
    cmp     ebx, [numvertexes]
    jae     .boundsdone
    imul    eax, ebx, VERTEX_SIZE
    mov     ecx, [vertexes + rax + VX_X]
    cmp     ecx, r8d
    jge     .b1
    mov     r8d, ecx
.b1:
    cmp     ecx, r10d
    jle     .b2
    mov     r10d, ecx
.b2:
    mov     ecx, [vertexes + rax + VX_Y]
    cmp     ecx, r9d
    jge     .b3
    mov     r9d, ecx
.b3:
    cmp     ecx, r11d
    jle     .b4
    mov     r11d, ecx
.b4:
    inc     ebx
    jmp     .bounds
.boundsdone:
    sub     r8d, 8*FRACUNIT
    sub     r9d, 8*FRACUNIT
    add     r10d, 8*FRACUNIT
    add     r11d, 8*FRACUNIT
    mov     [bmaporgx], r8d
    mov     [bmaporgy], r9d
    mov     eax, r10d
    sub     eax, r8d
    sar     eax, MAPBLOCKSHIFT
    inc     eax
    mov     [bmapwidth], eax
    mov     eax, r11d
    sub     eax, r9d
    sar     eax, MAPBLOCKSHIFT
    inc     eax
    mov     [bmapheight], eax
    mov     eax, [bmapwidth]
    imul    eax, [bmapheight]
    mov     [bmapnum], eax

    ; --- обнуление счётчиков ---
    xor     ebx, ebx
.clrcnt:
    cmp     ebx, [bmapnum]
    jae     .clrdone
    mov     dword [blockcount + rbx*4], 0
    mov     qword [blocklinks + rbx*8], 0
    inc     ebx
    jmp     .clrcnt
.clrdone:

    ; --- проход 1: подсчёт линий в блоках ---
    xor     ebx, ebx
.cnt:
    cmp     ebx, [numlines]
    jae     .cntdone
    imul    r12d, ebx, LINE_SIZE
    call    P_LineBlockRange            ; r8..r9 = bx1..bx2, r10..r11 = by1..by2
    mov     r14d, r10d
.cy1:
    cmp     r14d, r11d
    jg      .cnext
    mov     r15d, r8d
.cx1:
    cmp     r15d, r9d
    jg      .cy1n
    mov     eax, r14d
    imul    eax, [bmapwidth]
    add     eax, r15d
    inc     dword [blockcount + rax*4]
    inc     dword [blocktotal]
    inc     r15d
    jmp     .cx1
.cy1n:
    inc     r14d
    jmp     .cy1
.cnext:
    inc     ebx
    jmp     .cnt
.cntdone:

    ; --- префиксные суммы ---
    xor     ebx, ebx
    xor     r13d, r13d
.pref:
    cmp     ebx, [bmapnum]
    jae     .prefdone
    mov     [blockofs + rbx*4], r13d
    add     r13d, [blockcount + rbx*4]
    mov     dword [blockcount + rbx*4], 0
    inc     ebx
    jmp     .pref
.prefdone:

    ; --- проход 2: заполнение ---
    xor     ebx, ebx
.fil:
    cmp     ebx, [numlines]
    jae     .fildone
    imul    r12d, ebx, LINE_SIZE
    call    P_LineBlockRange
    mov     r14d, r10d
.fy1:
    cmp     r14d, r11d
    jg      .fnext
    mov     r15d, r8d
.fx1:
    cmp     r15d, r9d
    jg      .fy1n
    mov     eax, r14d
    imul    eax, [bmapwidth]
    add     eax, r15d
    mov     ecx, [blockofs + rax*4]
    add     ecx, [blockcount + rax*4]
    mov     [blocklists + rcx*4], ebx
    inc     dword [blockcount + rax*4]
    inc     r15d
    jmp     .fx1
.fy1n:
    inc     r14d
    jmp     .fy1
.fnext:
    inc     ebx
    jmp     .fil
.fildone:

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; r12d = смещение линии -> r8d..r9d диапазон X блоков, r10d..r11d диапазон Y
P_LineBlockRange:
    mov     eax, [lines + r12 + LN_BBOXLEFT]
    sub     eax, [bmaporgx]
    sar     eax, MAPBLOCKSHIFT
    mov     r8d, eax
    mov     eax, [lines + r12 + LN_BBOXRIGHT]
    sub     eax, [bmaporgx]
    sar     eax, MAPBLOCKSHIFT
    mov     r9d, eax
    mov     eax, [lines + r12 + LN_BBOXBOT]
    sub     eax, [bmaporgy]
    sar     eax, MAPBLOCKSHIFT
    mov     r10d, eax
    mov     eax, [lines + r12 + LN_BBOXTOP]
    sub     eax, [bmaporgy]
    sar     eax, MAPBLOCKSHIFT
    mov     r11d, eax
    ; отсечение
    test    r8d, r8d
    jns     .a1
    xor     r8d, r8d
.a1:
    test    r10d, r10d
    jns     .a2
    xor     r10d, r10d
.a2:
    mov     eax, [bmapwidth]
    dec     eax
    cmp     r9d, eax
    jle     .a3
    mov     r9d, eax
.a3:
    mov     eax, [bmapheight]
    dec     eax
    cmp     r11d, eax
    jle     .a4
    mov     r11d, eax
.a4:
    ret

; ---------------------------------------------------------------------------
;  P_PointOnLineSide(ecx=x, edx=y, r8d=смещение линии) -> eax (0 лицо, 1 тыл)
; ---------------------------------------------------------------------------
P_PointOnLineSide:
    push    rbx
    mov     eax, [lines + r8 + LN_V1]
    imul    eax, VERTEX_SIZE
    sub     ecx, [vertexes + rax + VX_X]        ; dx точки
    sub     edx, [vertexes + rax + VX_Y]        ; dy точки
    movsxd  r9, ecx
    movsxd  r10, edx
    ; left = line.dy * dx ; right = line.dx * dy  (64 бита, без переполнения)
    movsxd  rax, dword [lines + r8 + LN_DY]
    imul    rax, r9
    mov     rbx, rax                            ; left
    movsxd  rax, dword [lines + r8 + LN_DX]
    imul    rax, r10
    cmp     rax, rbx
    jl      .front
    mov     eax, 1
    pop     rbx
    ret
.front:
    xor     eax, eax
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_PointInSector(ecx=x, edx=y) -> eax = индекс сектора (или -1)
;  Секторы выпуклые: точка внутри, если она с внутренней стороны всех линий.
; ---------------------------------------------------------------------------
R_PointInSector:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r14d, ecx
    mov     r15d, edx
    xor     r12d, r12d                  ; сектор
.secloop:
    cmp     r12d, [numsectors]
    jae     .fail
    imul    r13d, r12d, SECTOR_SIZE
    ; быстрая проверка bbox
    cmp     r14d, [sectors + r13 + SEC_BBOXLEFT]
    jl      .secnext
    cmp     r14d, [sectors + r13 + SEC_BBOXRIGHT]
    jg      .secnext
    cmp     r15d, [sectors + r13 + SEC_BBOXBOT]
    jl      .secnext
    cmp     r15d, [sectors + r13 + SEC_BBOXTOP]
    jg      .secnext
    ; проверка всех линий
    mov     rdi, [sectors + r13 + SEC_LINES]
    xor     ebx, ebx
.lineloop:
    cmp     ebx, [sectors + r13 + SEC_LINECOUNT]
    jae     .found
    mov     esi, [rdi + rbx*4]          ; индекс линии
    imul    esi, LINE_SIZE
    mov     ecx, r14d
    mov     edx, r15d
    mov     r8d, esi
    call    P_PointOnLineSide
    ; нужная сторона: 0 если сектор лицевой, 1 если тыльный
    mov     ecx, 0
    cmp     [lines + rsi + LN_FRONTSEC], r12d
    je      .want
    mov     ecx, 1
.want:
    cmp     eax, ecx
    jne     .secnext
    inc     ebx
    jmp     .lineloop
.found:
    mov     eax, r12d
    jmp     .done
.secnext:
    inc     r12d
    jmp     .secloop
.fail:
    mov     eax, -1
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
