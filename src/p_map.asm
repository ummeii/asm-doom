; ===========================================================================
;  p_map.asm -- столкновения, скольжение вдоль стен, трассировка лучей,
;               проверка видимости, использование линий
;               (портирование p_map.c / p_sight.c из DOOM)
; ===========================================================================

%define BOXTOP      0
%define BOXBOTTOM   4
%define BOXLEFT     8
%define BOXRIGHT    12

%define MAXRADIUS   (32*FRACUNIT)
%define MAXSPECHIT  16
%define MAXINTERCEPTS 128

%define PT_ADDLINES  1
%define PT_ADDTHINGS 2
%define PT_EARLYOUT  4

%define IC_FRAC     0
%define IC_ISALINE  4
%define IC_PTR      8
%define IC_SIZE     16

; ---------------------------------------------------------------------------
;  P_LineOpening(r8d = смещение линии)
;    -> opentop, openbottom, openrange, lowfloor
; ---------------------------------------------------------------------------
P_LineOpening:
    cmp     dword [lines + r8 + LN_SIDE1], -1
    jne     .two
    mov     dword [openrange], 0
    ret
.two:
    mov     eax, [lines + r8 + LN_FRONTSEC]
    imul    eax, SECTOR_SIZE
    mov     edx, [lines + r8 + LN_BACKSEC]
    imul    edx, SECTOR_SIZE
    mov     ecx, [sectors + rax + SEC_CEILH]
    cmp     ecx, [sectors + rdx + SEC_CEILH]
    jl      .ct
    mov     ecx, [sectors + rdx + SEC_CEILH]
.ct:
    mov     [opentop], ecx
    mov     ecx, [sectors + rax + SEC_FLOORH]
    mov     r9d, [sectors + rdx + SEC_FLOORH]
    cmp     ecx, r9d
    jle     .fb
    mov     [openbottom], ecx
    mov     [lowfloor], r9d
    jmp     .fdone
.fb:
    mov     [openbottom], r9d
    mov     [lowfloor], ecx
.fdone:
    mov     eax, [opentop]
    sub     eax, [openbottom]
    mov     [openrange], eax
    ret

; ---------------------------------------------------------------------------
;  P_BoxOnLineSide(r8d = смещение линии) -> eax (-1 если пересекает)
;  Использует tmbbox.
; ---------------------------------------------------------------------------
P_BoxOnLineSide:
    push    rbx
    push    rsi
    mov     eax, [lines + r8 + LN_V1]
    imul    eax, VERTEX_SIZE
    mov     esi, eax
    mov     eax, [lines + r8 + LN_SLOPETYPE]
    cmp     eax, ST_HORIZONTAL
    je      .horiz
    cmp     eax, ST_VERTICAL
    je      .vert
    cmp     eax, ST_POSITIVE
    je      .pos
    ; ST_NEGATIVE
    mov     ecx, [tmbbox + BOXRIGHT]
    mov     edx, [tmbbox + BOXTOP]
    call    P_PointOnLineSide
    mov     ebx, eax
    mov     ecx, [tmbbox + BOXLEFT]
    mov     edx, [tmbbox + BOXBOTTOM]
    call    P_PointOnLineSide
    jmp     .cmp
.pos:
    mov     ecx, [tmbbox + BOXLEFT]
    mov     edx, [tmbbox + BOXTOP]
    call    P_PointOnLineSide
    mov     ebx, eax
    mov     ecx, [tmbbox + BOXRIGHT]
    mov     edx, [tmbbox + BOXBOTTOM]
    call    P_PointOnLineSide
    jmp     .cmp
.horiz:
    xor     ebx, ebx
    mov     ecx, [vertexes + rsi + VX_Y]
    cmp     [tmbbox + BOXTOP], ecx
    jle     .h1
    mov     ebx, 1
.h1:
    xor     eax, eax
    cmp     [tmbbox + BOXBOTTOM], ecx
    jle     .h2
    mov     eax, 1
.h2:
    cmp     dword [lines + r8 + LN_DX], 0
    jge     .cmp
    xor     ebx, 1
    xor     eax, 1
    jmp     .cmp
.vert:
    xor     ebx, ebx
    mov     ecx, [vertexes + rsi + VX_X]
    cmp     [tmbbox + BOXRIGHT], ecx
    jge     .v1
    mov     ebx, 1
.v1:
    xor     eax, eax
    cmp     [tmbbox + BOXLEFT], ecx
    jge     .v2
    mov     eax, 1
.v2:
    cmp     dword [lines + r8 + LN_DY], 0
    jge     .cmp
    xor     ebx, 1
    xor     eax, 1
.cmp:
    cmp     eax, ebx
    je      .same
    mov     eax, -1
.same:
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_CheckPosition(rcx = mobj, edx = x, r8d = y) -> eax (1 = можно)
; ---------------------------------------------------------------------------
P_CheckPosition:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     [tmthing], rcx
    mov     eax, [rcx + MO_FLAGS]
    mov     [tmflags], eax
    mov     [tmx], edx
    mov     [tmy], r8d
    mov     eax, [rcx + MO_RADIUS]
    mov     r9d, r8d
    add     r9d, eax
    mov     [tmbbox + BOXTOP], r9d
    mov     r9d, r8d
    sub     r9d, eax
    mov     [tmbbox + BOXBOTTOM], r9d
    mov     r9d, edx
    add     r9d, eax
    mov     [tmbbox + BOXRIGHT], r9d
    mov     r9d, edx
    sub     r9d, eax
    mov     [tmbbox + BOXLEFT], r9d

    mov     ecx, edx
    mov     edx, r8d
    call    R_PointInSector
    mov     [tmsector], eax
    cmp     eax, -1
    jne     .haveSec
    ; вне карты -- запрещаем
    xor     eax, eax
    jmp     .out
.haveSec:
    imul    eax, SECTOR_SIZE
    mov     ecx, [sectors + rax + SEC_FLOORH]
    mov     [tmfloorz], ecx
    mov     [tmdropoffz], ecx
    mov     ecx, [sectors + rax + SEC_CEILH]
    mov     [tmceilingz], ecx
    mov     dword [ceilingline], -1
    inc     dword [validcount]
    mov     dword [numspechit], 0

    test    dword [tmflags], MF_NOCLIP
    jz      .doclip
    mov     eax, 1
    jmp     .out
.doclip:

    ; ---- объекты ----
    mov     eax, [tmbbox + BOXLEFT]
    sub     eax, [bmaporgx]
    sub     eax, MAXRADIUS
    sar     eax, MAPBLOCKSHIFT
    mov     r12d, eax                   ; xl
    mov     eax, [tmbbox + BOXRIGHT]
    sub     eax, [bmaporgx]
    add     eax, MAXRADIUS
    sar     eax, MAPBLOCKSHIFT
    mov     r13d, eax                   ; xh
    mov     eax, [tmbbox + BOXBOTTOM]
    sub     eax, [bmaporgy]
    sub     eax, MAXRADIUS
    sar     eax, MAPBLOCKSHIFT
    mov     r14d, eax                   ; yl
    mov     eax, [tmbbox + BOXTOP]
    sub     eax, [bmaporgy]
    add     eax, MAXRADIUS
    sar     eax, MAPBLOCKSHIFT
    mov     r15d, eax                   ; yh
    mov     ebx, r12d
.tbx:
    cmp     ebx, r13d
    jg      .thingsdone
    mov     esi, r14d
.tby:
    cmp     esi, r15d
    jg      .tbxnext
    mov     ecx, ebx
    mov     edx, esi
    mov     r8, PIT_CheckThing
    call    P_BlockThingsIterator
    test    eax, eax
    jz      .blocked
    inc     esi
    jmp     .tby
.tbxnext:
    inc     ebx
    jmp     .tbx
.thingsdone:

    ; ---- линии ----
    mov     eax, [tmbbox + BOXLEFT]
    sub     eax, [bmaporgx]
    sar     eax, MAPBLOCKSHIFT
    mov     r12d, eax
    mov     eax, [tmbbox + BOXRIGHT]
    sub     eax, [bmaporgx]
    sar     eax, MAPBLOCKSHIFT
    mov     r13d, eax
    mov     eax, [tmbbox + BOXBOTTOM]
    sub     eax, [bmaporgy]
    sar     eax, MAPBLOCKSHIFT
    mov     r14d, eax
    mov     eax, [tmbbox + BOXTOP]
    sub     eax, [bmaporgy]
    sar     eax, MAPBLOCKSHIFT
    mov     r15d, eax
    mov     ebx, r12d
.lbx:
    cmp     ebx, r13d
    jg      .linesdone
    mov     esi, r14d
.lby:
    cmp     esi, r15d
    jg      .lbxnext
    mov     ecx, ebx
    mov     edx, esi
    mov     r8, PIT_CheckLine
    call    P_BlockLinesIterator
    test    eax, eax
    jz      .blocked
    inc     esi
    jmp     .lby
.lbxnext:
    inc     ebx
    jmp     .lbx
.linesdone:
    mov     eax, 1
    jmp     .out
.blocked:
    xor     eax, eax
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  PIT_CheckLine(r8d = смещение линии) -> eax (1 = продолжать)
; ---------------------------------------------------------------------------
PIT_CheckLine:
    push    rbx
    push    rsi
    mov     esi, r8d
    ; отсечение по bbox
    mov     eax, [tmbbox + BOXRIGHT]
    cmp     eax, [lines + rsi + LN_BBOXLEFT]
    jle     .ok
    mov     eax, [tmbbox + BOXLEFT]
    cmp     eax, [lines + rsi + LN_BBOXRIGHT]
    jge     .ok
    mov     eax, [tmbbox + BOXTOP]
    cmp     eax, [lines + rsi + LN_BBOXBOT]
    jle     .ok
    mov     eax, [tmbbox + BOXBOTTOM]
    cmp     eax, [lines + rsi + LN_BBOXTOP]
    jge     .ok
    call    P_BoxOnLineSide
    cmp     eax, -1
    jne     .ok
    ; линия пересекается
    cmp     dword [lines + rsi + LN_BACKSEC], -1
    je      .block
    mov     rbx, [tmthing]
    test    dword [rbx + MO_FLAGS], MF_MISSILE
    jnz     .nowall
    test    dword [lines + rsi + LN_FLAGS], ML_BLOCKING
    jnz     .block
    cmp     qword [rbx + MO_PLAYER], 0
    jne     .nowall
    test    dword [lines + rsi + LN_FLAGS], ML_BLOCKMONSTERS
    jnz     .block
.nowall:
    mov     r8d, esi
    call    P_LineOpening
    mov     eax, [opentop]
    cmp     eax, [tmceilingz]
    jge     .noct
    mov     [tmceilingz], eax
    mov     [ceilingline], esi
.noct:
    mov     eax, [openbottom]
    cmp     eax, [tmfloorz]
    jle     .nofl
    mov     [tmfloorz], eax
.nofl:
    mov     eax, [lowfloor]
    cmp     eax, [tmdropoffz]
    jge     .nodr
    mov     [tmdropoffz], eax
.nodr:
    cmp     dword [lines + rsi + LN_SPECIAL], 0
    je      .ok
    mov     eax, [numspechit]
    cmp     eax, MAXSPECHIT
    jae     .ok
    mov     [spechit + rax*4], esi
    inc     dword [numspechit]
.ok:
    mov     eax, 1
    pop     rsi
    pop     rbx
    ret
.block:
    xor     eax, eax
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  PIT_CheckThing(rcx = mobj) -> eax
; ---------------------------------------------------------------------------
PIT_CheckThing:
    push    rbx
    push    rsi
    push    rdi
    mov     rbx, rcx
    mov     eax, [rbx + MO_FLAGS]
    test    eax, MF_SOLID|MF_SPECIAL|MF_SHOOTABLE
    jz      .ok
    mov     rsi, [tmthing]
    cmp     rbx, rsi
    je      .ok
    ; расстояние
    mov     eax, [rbx + MO_RADIUS]
    add     eax, [rsi + MO_RADIUS]
    mov     edi, eax                    ; blockdist
    mov     eax, [rbx + MO_X]
    sub     eax, [tmx]
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    cmp     eax, edi
    jge     .ok
    mov     eax, [rbx + MO_Y]
    sub     eax, [tmy]
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    cmp     eax, edi
    jge     .ok

    ; --- летящий череп ---
    test    dword [rsi + MO_FLAGS], MF_SKULLFLY
    jz      .noskull
    call    P_Random
    and     eax, 7
    inc     eax
    mov     rdx, [rsi + MO_INFO]
    imul    eax, [rdx + MI_DAMAGE]
    mov     rcx, rbx
    mov     rdx, rsi
    mov     r8, rsi
    mov     r9d, eax
    call    P_DamageMobj
    and     dword [rsi + MO_FLAGS], ~MF_SKULLFLY
    mov     dword [rsi + MO_MOMX], 0
    mov     dword [rsi + MO_MOMY], 0
    mov     dword [rsi + MO_MOMZ], 0
    mov     rcx, rsi
    mov     rdx, [rsi + MO_INFO]
    mov     edx, [rdx + MI_SPAWNSTATE]
    call    P_SetMobjState
    jmp     .stop

.noskull:
    ; --- снаряд ---
    test    dword [rsi + MO_FLAGS], MF_MISSILE
    jz      .nomissile
    mov     eax, [rbx + MO_Z]
    add     eax, [rbx + MO_HEIGHT]
    cmp     [rsi + MO_Z], eax
    jg      .ok
    mov     eax, [rsi + MO_Z]
    add     eax, [rsi + MO_HEIGHT]
    cmp     eax, [rbx + MO_Z]
    jl      .ok
    ; свои не бьют своих
    mov     rdx, [rsi + MO_TARGET]
    test    rdx, rdx
    jz      .candamage
    mov     eax, [rdx + MO_TYPE]
    cmp     eax, [rbx + MO_TYPE]
    jne     .candamage
    cmp     rbx, rdx
    je      .ok
    cmp     dword [rbx + MO_TYPE], MT_PLAYER
    jne     .stop
.candamage:
    test    dword [rbx + MO_FLAGS], MF_SHOOTABLE
    jnz     .domissiledmg
    test    dword [rbx + MO_FLAGS], MF_SOLID
    jz      .ok
    jmp     .stop
.domissiledmg:
    call    P_Random
    and     eax, 7
    inc     eax
    mov     rdx, [rsi + MO_INFO]
    imul    eax, [rdx + MI_DAMAGE]
    mov     rcx, rbx
    mov     rdx, rsi
    mov     r8, [rsi + MO_TARGET]
    mov     r9d, eax
    call    P_DamageMobj
    jmp     .stop

.nomissile:
    ; --- подбираемый предмет ---
    test    dword [rbx + MO_FLAGS], MF_SPECIAL
    jz      .solidchk
    mov     edi, [rbx + MO_FLAGS]
    and     edi, MF_SOLID
    test    dword [tmflags], MF_PICKUP
    jz      .nopickup
    mov     rcx, rbx
    mov     rdx, [tmthing]
    call    P_TouchSpecialThing
.nopickup:
    test    edi, edi
    jnz     .stop
    jmp     .ok
.solidchk:
    test    dword [rbx + MO_FLAGS], MF_SOLID
    jnz     .stop
.ok:
    mov     eax, 1
    pop     rdi
    pop     rsi
    pop     rbx
    ret
.stop:
    xor     eax, eax
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_TryMove(rcx = mobj, edx = x, r8d = y) -> eax
; ---------------------------------------------------------------------------
P_TryMove:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    mov     rbx, rcx
    mov     r12d, edx
    mov     r13d, r8d
    mov     dword [floatok], 0
    call    P_CheckPosition
    test    eax, eax
    jz      .fail

    test    dword [rbx + MO_FLAGS], MF_NOCLIP
    jnz     .okmove
    mov     eax, [tmceilingz]
    sub     eax, [tmfloorz]
    cmp     eax, [rbx + MO_HEIGHT]
    jl      .fail
    mov     dword [floatok], 1
    test    dword [rbx + MO_FLAGS], MF_TELEPORT
    jnz     .noheightchk
    mov     eax, [tmceilingz]
    sub     eax, [rbx + MO_Z]
    cmp     eax, [rbx + MO_HEIGHT]
    jl      .fail
    mov     eax, [tmfloorz]
    sub     eax, [rbx + MO_Z]
    cmp     eax, 24*FRACUNIT
    jg      .fail
.noheightchk:
    mov     eax, [rbx + MO_FLAGS]
    and     eax, MF_DROPOFF|MF_FLOAT
    jnz     .okmove
    mov     eax, [tmfloorz]
    sub     eax, [tmdropoffz]
    cmp     eax, 24*FRACUNIT
    jg      .fail
.okmove:
    mov     rcx, rbx
    call    P_UnsetThingPosition
    mov     esi, [rbx + MO_X]
    mov     edi, [rbx + MO_Y]
    mov     eax, [tmfloorz]
    mov     [rbx + MO_FLOORZ], eax
    mov     eax, [tmceilingz]
    mov     [rbx + MO_CEILINGZ], eax
    mov     eax, [tmdropoffz]
    mov     [rbx + MO_DROPOFFZ], eax
    mov     [rbx + MO_X], r12d
    mov     [rbx + MO_Y], r13d
    mov     rcx, rbx
    call    P_SetThingPosition

    ; пересечённые специальные линии
    mov     eax, [rbx + MO_FLAGS]
    and     eax, MF_TELEPORT|MF_NOCLIP
    jnz     .done
.spec:
    cmp     dword [numspechit], 0
    je      .done
    dec     dword [numspechit]
    mov     eax, [numspechit]
    mov     r8d, [spechit + rax*4]
    push    r8
    mov     ecx, [rbx + MO_X]
    mov     edx, [rbx + MO_Y]
    call    P_PointOnLineSide
    mov     r9d, eax
    pop     r8
    push    r8
    push    r9
    mov     ecx, esi
    mov     edx, edi
    call    P_PointOnLineSide
    pop     r9
    pop     r8
    cmp     eax, r9d
    je      .spec
    mov     ecx, r8d
    mov     edx, eax
    mov     r8, rbx
    call    P_CrossSpecialLine
    jmp     .spec
.done:
    mov     eax, 1
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
.fail:
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_BlockLinesIterator(ecx = bx, edx = by, r8 = функция) -> eax
;  Функция вызывается с r8d = смещение линии, возвращает eax.
; ---------------------------------------------------------------------------
P_BlockLinesIterator:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    mov     r12, r8
    test    ecx, ecx
    js      .ok
    test    edx, edx
    js      .ok
    cmp     ecx, [bmapwidth]
    jge     .ok
    cmp     edx, [bmapheight]
    jge     .ok
    mov     eax, edx
    imul    eax, [bmapwidth]
    add     eax, ecx
    mov     esi, [blockofs + rax*4]     ; начало списка
    mov     edi, [blockcount + rax*4]   ; количество
    xor     ebx, ebx
.l:
    cmp     ebx, edi
    jae     .ok
    mov     eax, esi
    add     eax, ebx
    mov     eax, [blocklists + rax*4]   ; индекс линии
    imul    eax, LINE_SIZE
    cmp     dword [lines + rax + LN_VALID], 0
    jl      .next
    mov     ecx, [validcount]
    cmp     [lines + rax + LN_VALID], ecx
    je      .next
    mov     [lines + rax + LN_VALID], ecx
    mov     r8d, eax
    call    r12
    test    eax, eax
    jz      .stop
.next:
    inc     ebx
    jmp     .l
.ok:
    mov     eax, 1
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
.stop:
    xor     eax, eax
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_BlockThingsIterator(ecx = bx, edx = by, r8 = функция) -> eax
;  Функция вызывается с rcx = mobj.
; ---------------------------------------------------------------------------
P_BlockThingsIterator:
    push    rbx
    push    rsi
    push    r12
    mov     r12, r8
    test    ecx, ecx
    js      .ok
    test    edx, edx
    js      .ok
    cmp     ecx, [bmapwidth]
    jge     .ok
    cmp     edx, [bmapheight]
    jge     .ok
    mov     eax, edx
    imul    eax, [bmapwidth]
    add     eax, ecx
    mov     rbx, [blocklinks + rax*8]
.l:
    test    rbx, rbx
    jz      .ok
    mov     rsi, [rbx + MO_BNEXT]
    mov     rcx, rbx
    call    r12
    test    eax, eax
    jz      .stop
    mov     rbx, rsi
    jmp     .l
.ok:
    mov     eax, 1
    pop     r12
    pop     rsi
    pop     rbx
    ret
.stop:
    xor     eax, eax
    pop     r12
    pop     rsi
    pop     rbx
    ret

; ===========================================================================
;  Трассировка пути (P_PathTraverse)
; ===========================================================================

; P_InterceptVector(divline A в rcx, divline B в rdx) -> eax = frac
;  divline: x(0), y(4), dx(8), dy(12)
P_InterceptVector:
    push    rbx
    push    rsi
    ; den = FixedMul(v1->dy>>8, v2->dx) - FixedMul(v1->dx>>8, v2->dy)
    mov     rsi, rcx
    mov     rbx, rdx
    mov     ecx, [rsi + 12]
    sar     ecx, 8
    mov     edx, [rbx + 8]
    call    FixedMul
    mov     r10d, eax
    mov     ecx, [rsi + 8]
    sar     ecx, 8
    mov     edx, [rbx + 12]
    call    FixedMul
    sub     r10d, eax                   ; den
    test    r10d, r10d
    jnz     .nz
    xor     eax, eax
    pop     rsi
    pop     rbx
    ret
.nz:
    push    r10
    mov     ecx, [rsi + 0]
    sub     ecx, [rbx + 0]
    sar     ecx, 8
    mov     edx, [rbx + 12]
    call    FixedMul
    mov     r11d, eax
    mov     ecx, [rbx + 4]
    sub     ecx, [rsi + 4]
    sar     ecx, 8
    mov     edx, [rbx + 8]
    call    FixedMul
    add     eax, r11d                   ; num
    pop     r10
    mov     ecx, eax
    mov     edx, r10d
    call    FixedDiv
    pop     rsi
    pop     rbx
    ret

; PIT_AddLineIntercepts(r8d = смещение линии)
PIT_AddLineIntercepts:
    push    rbx
    push    rsi
    push    rdi
    mov     esi, r8d
    ; сторона обоих концов линии трассы относительно линии
    mov     eax, [lines + rsi + LN_V1]
    imul    eax, VERTEX_SIZE
    mov     ecx, [vertexes + rax + VX_X]
    mov     edx, [vertexes + rax + VX_Y]
    mov     [ldv + 0], ecx
    mov     [ldv + 4], edx
    mov     eax, [lines + rsi + LN_DX]
    mov     [ldv + 8], eax
    mov     eax, [lines + rsi + LN_DY]
    mov     [ldv + 12], eax
    ; P_PointOnDivlineSide для концов трассы
    mov     ecx, [trace + 0]
    mov     edx, [trace + 4]
    mov     r8, ldv
    call    P_PointOnDivlineSide
    mov     ebx, eax
    mov     ecx, [trace + 0]
    add     ecx, [trace + 8]
    mov     edx, [trace + 4]
    add     edx, [trace + 12]
    mov     r8, ldv
    call    P_PointOnDivlineSide
    cmp     eax, ebx
    je      .skip
    mov     rcx, trace
    mov     rdx, ldv
    call    P_InterceptVector
    test    eax, eax
    js      .skip
    mov     ecx, [numintercepts]
    cmp     ecx, MAXINTERCEPTS
    jae     .skip
    imul    ecx, IC_SIZE
    mov     [intercepts + rcx + IC_FRAC], eax
    mov     dword [intercepts + rcx + IC_ISALINE], 1
    mov     [intercepts + rcx + IC_PTR], rsi
    inc     dword [numintercepts]
.skip:
    mov     eax, 1
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; PIT_AddThingIntercepts(rcx = mobj)
PIT_AddThingIntercepts:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    mov     rbx, rcx
    mov     eax, [rbx + MO_RADIUS]
    mov     r12d, eax
    ; выбираем диагональ прямоугольника по направлению трассы
    mov     ecx, [trace + 8]
    mov     edx, [trace + 12]
    xor     r8d, r8d
    test    ecx, ecx
    jns     .dx1
    mov     r8d, 1
.dx1:
    test    edx, edx
    jns     .dy1
    xor     r8d, 1
.dy1:
    mov     ecx, [rbx + MO_X]
    mov     edx, [rbx + MO_Y]
    test    r8d, r8d
    jz      .diag0
    ; \ диагональ
    sub     ecx, r12d
    sub     edx, r12d
    mov     [ldv + 0], ecx
    mov     [ldv + 4], edx
    mov     eax, r12d
    add     eax, eax
    mov     [ldv + 8], eax
    mov     [ldv + 12], eax
    jmp     .have
.diag0:
    ; / диагональ
    sub     ecx, r12d
    add     edx, r12d
    mov     [ldv + 0], ecx
    mov     [ldv + 4], edx
    mov     eax, r12d
    add     eax, eax
    mov     [ldv + 8], eax
    neg     eax
    mov     [ldv + 12], eax
.have:
    mov     ecx, [trace + 0]
    mov     edx, [trace + 4]
    mov     r8, ldv
    call    P_PointOnDivlineSide
    mov     esi, eax
    mov     ecx, [trace + 0]
    add     ecx, [trace + 8]
    mov     edx, [trace + 4]
    add     edx, [trace + 12]
    mov     r8, ldv
    call    P_PointOnDivlineSide
    cmp     eax, esi
    je      .skip
    mov     rcx, trace
    mov     rdx, ldv
    call    P_InterceptVector
    test    eax, eax
    js      .skip
    mov     ecx, [numintercepts]
    cmp     ecx, MAXINTERCEPTS
    jae     .skip
    imul    ecx, IC_SIZE
    mov     [intercepts + rcx + IC_FRAC], eax
    mov     dword [intercepts + rcx + IC_ISALINE], 0
    mov     [intercepts + rcx + IC_PTR], rbx
    inc     dword [numintercepts]
.skip:
    mov     eax, 1
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; P_PointOnDivlineSide(ecx=x, edx=y, r8=divline) -> eax
P_PointOnDivlineSide:
    push    rbx
    mov     eax, [r8 + 8]
    or      eax, [r8 + 12]
    jnz     .general
    xor     eax, eax
    pop     rbx
    ret
.general:
    sub     ecx, [r8 + 0]
    sub     edx, [r8 + 4]
    movsxd  r9, ecx
    movsxd  r10, edx
    movsxd  rax, dword [r8 + 12]
    imul    rax, r9
    mov     rbx, rax                    ; left
    movsxd  rax, dword [r8 + 8]
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
;  P_PathTraverse(x1,y1,x2,y2 в [pt_x1..pt_y2], ecx = флаги, rdx = функция)
;   -> eax (1 если дошли до конца)
; ---------------------------------------------------------------------------
P_PathTraverse:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     [pt_flags], ecx
    mov     [pt_func], rdx

    inc     dword [validcount]
    mov     dword [numintercepts], 0

    mov     eax, [pt_x1]
    sub     eax, [bmaporgx]
    and     eax, MAPBLOCKSIZE-1
    jnz     .nx
    add     dword [pt_x1], FRACUNIT
.nx:
    mov     eax, [pt_y1]
    sub     eax, [bmaporgy]
    and     eax, MAPBLOCKSIZE-1
    jnz     .ny
    add     dword [pt_y1], FRACUNIT
.ny:
    mov     eax, [pt_x1]
    mov     [trace + 0], eax
    mov     eax, [pt_y1]
    mov     [trace + 4], eax
    mov     eax, [pt_x2]
    sub     eax, [pt_x1]
    mov     [trace + 8], eax
    mov     eax, [pt_y2]
    sub     eax, [pt_y1]
    mov     [trace + 12], eax

    mov     r12d, [pt_x1]
    sub     r12d, [bmaporgx]            ; x1
    mov     r13d, [pt_y1]
    sub     r13d, [bmaporgy]            ; y1
    mov     r14d, [pt_x2]
    sub     r14d, [bmaporgx]            ; x2
    mov     r15d, [pt_y2]
    sub     r15d, [bmaporgy]            ; y2
    mov     eax, r12d
    sar     eax, MAPBLOCKSHIFT
    mov     [pt_xt1], eax
    mov     eax, r13d
    sar     eax, MAPBLOCKSHIFT
    mov     [pt_yt1], eax
    mov     eax, r14d
    sar     eax, MAPBLOCKSHIFT
    mov     [pt_xt2], eax
    mov     eax, r15d
    sar     eax, MAPBLOCKSHIFT
    mov     [pt_yt2], eax

    ; --- шаг по X ---
    mov     eax, [pt_xt2]
    cmp     eax, [pt_xt1]
    jle     .xle
    mov     dword [pt_mapxstep], 1
    mov     eax, r12d
    sar     eax, MAPBTOFRAC
    and     eax, FRACUNIT-1
    mov     ecx, FRACUNIT
    sub     ecx, eax
    mov     [pt_partial], ecx
    jmp     .xystep
.xle:
    jge     .xeq
    mov     dword [pt_mapxstep], -1
    mov     eax, r12d
    sar     eax, MAPBTOFRAC
    and     eax, FRACUNIT-1
    mov     [pt_partial], eax
    jmp     .xystep
.xeq:
    mov     dword [pt_mapxstep], 0
    mov     dword [pt_partial], FRACUNIT
    mov     dword [pt_ystep], 256*FRACUNIT
    jmp     .yintr
.xystep:
    mov     eax, r14d
    sub     eax, r12d
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx                    ; abs(x2-x1)
    mov     edx, eax
    mov     ecx, r15d
    sub     ecx, r13d
    call    FixedDiv
    mov     [pt_ystep], eax
.yintr:
    mov     eax, r13d
    sar     eax, MAPBTOFRAC
    mov     r8d, eax
    mov     ecx, [pt_partial]
    mov     edx, [pt_ystep]
    call    FixedMul
    add     eax, r8d
    mov     [pt_yintercept], eax

    ; --- шаг по Y ---
    mov     eax, [pt_yt2]
    cmp     eax, [pt_yt1]
    jle     .yle
    mov     dword [pt_mapystep], 1
    mov     eax, r13d
    sar     eax, MAPBTOFRAC
    and     eax, FRACUNIT-1
    mov     ecx, FRACUNIT
    sub     ecx, eax
    mov     [pt_partial], ecx
    jmp     .yxstep
.yle:
    jge     .yeq
    mov     dword [pt_mapystep], -1
    mov     eax, r13d
    sar     eax, MAPBTOFRAC
    and     eax, FRACUNIT-1
    mov     [pt_partial], eax
    jmp     .yxstep
.yeq:
    mov     dword [pt_mapystep], 0
    mov     dword [pt_partial], FRACUNIT
    mov     dword [pt_xstep], 256*FRACUNIT
    jmp     .xintr
.yxstep:
    mov     eax, r15d
    sub     eax, r13d
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    mov     edx, eax
    mov     ecx, r14d
    sub     ecx, r12d
    call    FixedDiv
    mov     [pt_xstep], eax
.xintr:
    mov     eax, r12d
    sar     eax, MAPBTOFRAC
    mov     r8d, eax
    mov     ecx, [pt_partial]
    mov     edx, [pt_xstep]
    call    FixedMul
    add     eax, r8d
    mov     [pt_xintercept], eax

    ; --- обход блоков ---
    mov     ebx, [pt_xt1]               ; mapx
    mov     esi, [pt_yt1]               ; mapy
    xor     edi, edi                    ; счётчик
.walk:
    cmp     edi, 64
    jae     .walkdone
    test    dword [pt_flags], PT_ADDLINES
    jz      .nolines
    mov     ecx, ebx
    mov     edx, esi
    mov     r8, PIT_AddLineIntercepts
    call    P_BlockLinesIterator
    test    eax, eax
    jz      .fail
.nolines:
    test    dword [pt_flags], PT_ADDTHINGS
    jz      .nothings
    mov     ecx, ebx
    mov     edx, esi
    mov     r8, PIT_AddThingIntercepts
    call    P_BlockThingsIterator
    test    eax, eax
    jz      .fail
.nothings:
    cmp     ebx, [pt_xt2]
    jne     .step
    cmp     esi, [pt_yt2]
    je      .walkdone
.step:
    mov     eax, [pt_yintercept]
    sar     eax, FRACBITS
    cmp     eax, esi
    jne     .stepy
    mov     eax, [pt_ystep]
    add     [pt_yintercept], eax
    add     ebx, [pt_mapxstep]
    jmp     .stepnext
.stepy:
    mov     eax, [pt_xintercept]
    sar     eax, FRACBITS
    cmp     eax, ebx
    jne     .stepnext
    mov     eax, [pt_xstep]
    add     [pt_xintercept], eax
    add     esi, [pt_mapystep]
.stepnext:
    inc     edi
    jmp     .walk
.walkdone:
    mov     ecx, FRACUNIT
    call    P_TraverseIntercepts
    jmp     .out
.fail:
    xor     eax, eax
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_TraverseIntercepts(ecx = maxfrac) -> eax
; ---------------------------------------------------------------------------
P_TraverseIntercepts:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    mov     r13d, ecx
    mov     r12d, [numintercepts]
.loop:
    test    r12d, r12d
    jz      .ok
    ; ищем ближайший
    mov     eax, MAXINT
    mov     esi, -1
    xor     ebx, ebx
.find:
    cmp     ebx, [numintercepts]
    jae     .founddone
    imul    ecx, ebx, IC_SIZE
    mov     edx, [intercepts + rcx + IC_FRAC]
    cmp     edx, eax
    jge     .findnext
    mov     eax, edx
    mov     esi, ebx
.findnext:
    inc     ebx
    jmp     .find
.founddone:
    cmp     esi, -1
    je      .ok
    cmp     eax, r13d
    jg      .ok
    lea     rcx, [intercepts]
    imul    edx, esi, IC_SIZE
    add     rcx, rdx
    mov     [ic_frac], eax
    push    rdx
    call    [pt_func]
    pop     rdx
    test    eax, eax
    jz      .stop
    mov     dword [intercepts + rdx + IC_FRAC], MAXINT   ; помечаем использованным
    dec     r12d
    jmp     .loop
.ok:
    mov     eax, 1
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
.stop:
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
