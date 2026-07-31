; ===========================================================================
;  r_main.asm -- вид, обход секторов через порталы, отрисовка стен
;
;  Вместо BSP используется портальный обход: сектор выпуклый, поэтому его
;  лицевые стены не перекрывают друг друга по X. Дальше всё как в DOOM --
;  drawseg'и с силуэтами, визплейны, ceilingclip/floorclip.
; ===========================================================================

%define FIELDOFVIEW     2048
%define MAXPORTALDEPTH  32
%define HEIGHTBITS      12
%define HEIGHTUNIT      (1<<HEIGHTBITS)

%define SIL_NONE        0
%define SIL_BOTTOM      1
%define SIL_TOP         2
%define SIL_BOTH        3

%define DS_X1           0
%define DS_X2           4
%define DS_SCALE1       8
%define DS_SCALE2       12
%define DS_SCALESTEP    16
%define DS_SILHOUETTE   20
%define DS_BSILHEIGHT   24
%define DS_TSILHEIGHT   28
%define DS_SPRTOPCLIP   32
%define DS_SPRBOTCLIP   40
%define DS_MASKEDCOL    48
%define DS_LINEOFS      56
%define DS_FRONTSEC     60
%define DS_BACKSEC      64
%define DS_TEXMID       68
%define DS_LIGHTS       72
%define DS_SIDEOFS      80
%define DS_PAD          84
%define DRAWSEG_SIZE    88
%define MAXDRAWSEGS     2048
%define MAXOPENINGS     (SCREENWIDTH*256)

; ---------------------------------------------------------------------------
;  R_InitRender
; ---------------------------------------------------------------------------
R_InitRender:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13

    mov     dword [viewwidth], SCREENWIDTH
    mov     dword [viewheight], SCREENHEIGHT-32
    mov     dword [centerx], SCREENWIDTH/2
    mov     eax, [viewheight]
    shr     eax, 1
    mov     [centery], eax
    mov     eax, [centerx]
    shl     eax, 16
    mov     [centerxfrac], eax
    mov     [projection], eax
    mov     eax, [centery]
    shl     eax, 16
    mov     [centeryfrac], eax
    mov     dword [pspritescale], FRACUNIT
    mov     dword [pspriteiscale], FRACUNIT
    mov     dword [skytexturemid], 100*FRACUNIT

    call    R_InitTextureMapping

    ; --- yslope[] ---
    xor     ebx, ebx
.ysl:
    mov     eax, [viewheight]
    shr     eax, 1
    mov     ecx, ebx
    sub     ecx, eax
    shl     ecx, 16
    add     ecx, FRACUNIT/2
    mov     eax, ecx
    sar     eax, 31
    xor     ecx, eax
    sub     ecx, eax                    ; abs
    mov     edx, ecx
    mov     ecx, SCREENWIDTH/2*FRACUNIT
    call    FixedDiv
    mov     [yslope + rbx*4], eax
    inc     ebx
    cmp     ebx, SCREENHEIGHT
    jb      .ysl

    ; --- distscale[] ---
    xor     ebx, ebx
.dsc:
    mov     eax, [xtoviewangle + rbx*4]
    shr     eax, ANGLETOFINESHIFT
    and     eax, FINEMASK
    mov     eax, [finecosine + rax*4]
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    mov     edx, eax
    mov     ecx, FRACUNIT
    call    FixedDiv
    mov     [distscale + rbx*4], eax
    inc     ebx
    cmp     ebx, SCREENWIDTH
    jb      .dsc

    ; --- таблицы освещения ---
    xor     r12d, r12d                  ; i = уровень света
.lt1:
    mov     eax, LIGHTLEVELS-1
    sub     eax, r12d
    shl     eax, 1
    imul    eax, NUMCOLORMAPS
    xor     edx, edx
    mov     ecx, LIGHTLEVELS
    div     ecx
    mov     r13d, eax                   ; startmap
    ; zlight
    xor     ebx, ebx
.lt2:
    mov     ecx, ebx
    inc     ecx
    shl     ecx, LIGHTZSHIFT
    mov     edx, ecx
    mov     ecx, SCREENWIDTH/2*FRACUNIT
    call    FixedDiv
    sar     eax, LIGHTSCALESHIFT
    xor     edx, edx
    mov     ecx, DISTMAP
    div     ecx
    mov     ecx, r13d
    sub     ecx, eax
    call    R_ClampLevel
    shl     eax, 8
    lea     rdx, [colormaps]
    add     rdx, rax
    mov     eax, r12d
    imul    eax, MAXLIGHTZ
    add     eax, ebx
    lea     rcx, [zlight]
    mov     [rcx + rax*8], rdx
    inc     ebx
    cmp     ebx, MAXLIGHTZ
    jb      .lt2
    ; scalelight
    xor     ebx, ebx
.lt3:
    mov     eax, ebx
    imul    eax, SCREENWIDTH
    xor     edx, edx
    mov     ecx, [viewwidth]
    div     ecx
    xor     edx, edx
    mov     ecx, DISTMAP
    div     ecx
    mov     ecx, r13d
    sub     ecx, eax
    call    R_ClampLevel
    shl     eax, 8
    lea     rdx, [colormaps]
    add     rdx, rax
    mov     eax, r12d
    imul    eax, MAXLIGHTSCALE
    add     eax, ebx
    lea     rcx, [scalelight]
    mov     [rcx + rax*8], rdx
    inc     ebx
    cmp     ebx, MAXLIGHTSCALE
    jb      .lt3
    inc     r12d
    cmp     r12d, LIGHTLEVELS
    jb      .lt1

    ; --- вспомогательные массивы ---
    xor     ebx, ebx
.arr:
    mov     eax, [viewheight]
    mov     [screenheightarray + rbx*4], eax
    mov     dword [negonearray + rbx*4], -1
    inc     ebx
    cmp     ebx, SCREENWIDTH
    jb      .arr

    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ecx -> eax, ограничение 0..NUMCOLORMAPS-1
R_ClampLevel:
    mov     eax, ecx
    test    eax, eax
    jns     .p
    xor     eax, eax
    ret
.p: cmp     eax, NUMCOLORMAPS
    jl      .ok
    mov     eax, NUMCOLORMAPS-1
.ok:
    ret

; ---------------------------------------------------------------------------
;  R_InitTextureMapping
; ---------------------------------------------------------------------------
R_InitTextureMapping:
    push    rbx
    push    rsi
    push    rdi
    ; focallength = FixedDiv(centerxfrac, finetangent[2048 + 1024])
    mov     ecx, [centerxfrac]
    mov     edx, [finetangent + (FINEANGLES/4 + FIELDOFVIEW/2)*4]
    call    FixedDiv
    mov     [focallength], eax

    xor     ebx, ebx
.l1:
    mov     eax, [finetangent + rbx*4]
    cmp     eax, FRACUNIT*2
    jle     .n1
    mov     dword [viewangletox + rbx*4], -1
    jmp     .nx1
.n1:
    cmp     eax, -FRACUNIT*2
    jge     .n2
    mov     eax, [viewwidth]
    inc     eax
    mov     [viewangletox + rbx*4], eax
    jmp     .nx1
.n2:
    mov     ecx, eax
    mov     edx, [focallength]
    call    FixedMul
    mov     ecx, [centerxfrac]
    sub     ecx, eax
    add     ecx, FRACUNIT-1
    sar     ecx, FRACBITS
    cmp     ecx, -1
    jge     .n3
    mov     ecx, -1
.n3:
    mov     eax, [viewwidth]
    inc     eax
    cmp     ecx, eax
    jle     .n4
    mov     ecx, eax
.n4:
    mov     [viewangletox + rbx*4], ecx
.nx1:
    inc     ebx
    cmp     ebx, FINEANGLES/2
    jb      .l1

    ; xtoviewangle
    xor     ebx, ebx
.l2:
    xor     esi, esi
.l2a:
    mov     eax, [viewangletox + rsi*4]
    cmp     eax, ebx
    jle     .l2b
    inc     esi
    cmp     esi, FINEANGLES/2
    jb      .l2a
.l2b:
    mov     eax, esi
    shl     eax, ANGLETOFINESHIFT
    sub     eax, ANG90
    mov     [xtoviewangle + rbx*4], eax
    inc     ebx
    cmp     ebx, SCREENWIDTH
    jbe     .l2

    ; нормализация краёв
    xor     ebx, ebx
.l3:
    mov     eax, [viewangletox + rbx*4]
    cmp     eax, -1
    jne     .l3a
    mov     dword [viewangletox + rbx*4], 0
    jmp     .l3b
.l3a:
    mov     ecx, [viewwidth]
    inc     ecx
    cmp     eax, ecx
    jne     .l3b
    mov     eax, [viewwidth]
    mov     [viewangletox + rbx*4], eax
.l3b:
    inc     ebx
    cmp     ebx, FINEANGLES/2
    jb      .l3

    mov     eax, [xtoviewangle]
    mov     [clipangle], eax
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_SetupFrame -- позиция и угол камеры от игрока
; ---------------------------------------------------------------------------
R_SetupFrame:
    push    rbx
    mov     rbx, [playermo]
    mov     eax, [rbx + MO_X]
    mov     [viewx], eax
    mov     eax, [rbx + MO_Y]
    mov     [viewy], eax
    mov     eax, [rbx + MO_ANGLE]
    mov     [viewangle], eax
    mov     eax, [player + PL_VIEWZ]
    mov     [viewz], eax
    mov     eax, [rbx + MO_SECTOR]
    mov     [viewsector], eax
    mov     eax, [viewangle]
    shr     eax, ANGLETOFINESHIFT
    and     eax, FINEMASK
    mov     ecx, [finesine + rax*4]
    mov     [viewsin], ecx
    mov     ecx, [finecosine + rax*4]
    mov     [viewcos], ecx
    mov     eax, [player + PL_EXTRALIGHT]
    mov     [extralight], eax
    ; фиксированная карта цветов (неуязвимость / инфразрение)
    mov     qword [fixedcolormap], 0
    mov     eax, [player + PL_FIXEDCOLORMAP]
    test    eax, eax
    jz      .nofixed
    shl     eax, 8
    lea     rdx, [colormaps]
    add     rdx, rax
    mov     [fixedcolormap], rdx
.nofixed:
    inc     dword [validcount]
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_RenderPlayerView
; ---------------------------------------------------------------------------
R_RenderPlayerView:
    push    rbx
    call    R_SetupFrame
    call    R_ClearPlanes
    call    R_ClearSprites
    mov     dword [ds_index], 0
    mov     dword [portaldepth], 0
    mov     ecx, [viewsector]
    cmp     ecx, -1
    je      .nosec
    xor     edx, edx
    mov     r8d, [viewwidth]
    dec     r8d
    call    R_RenderSector
.nosec:
    call    R_DrawPlanes
    call    R_DrawMasked
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_RenderSector(ecx = сектор, edx = x1, r8d = x2)
; ---------------------------------------------------------------------------
R_RenderSector:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12d, ecx                   ; сектор
    mov     r13d, edx                   ; x1
    mov     r14d, r8d                   ; x2

    cmp     r13d, r14d
    jg      .done
    cmp     dword [portaldepth], MAXPORTALDEPTH
    jge     .done
    inc     dword [portaldepth]

    ; --- объекты сектора ---
    mov     ecx, r12d
    call    R_AddSprites

    imul    esi, r12d, SECTOR_SIZE      ; смещение сектора

    ; --- плоскости сектора ---
    mov     eax, [sectors + rsi + SEC_FLOORH]
    cmp     eax, [viewz]
    jl      .mkfloor
    mov     eax, [sectors + rsi + SEC_FLOORPIC]
    cmp     eax, [skyflatnum]
    je      .mkfloor
    mov     qword [floorplane], 0
    jmp     .floordone
.mkfloor:
    mov     ecx, [sectors + rsi + SEC_FLOORH]
    mov     edx, [sectors + rsi + SEC_FLOORPIC]
    mov     r8d, [sectors + rsi + SEC_LIGHT]
    call    R_FindPlane
    mov     [floorplane], rax
.floordone:
    mov     eax, [sectors + rsi + SEC_CEILH]
    cmp     eax, [viewz]
    jg      .mkceil
    mov     eax, [sectors + rsi + SEC_CEILPIC]
    cmp     eax, [skyflatnum]
    je      .mkceil
    mov     qword [ceilingplane], 0
    jmp     .ceildone
.mkceil:
    mov     ecx, [sectors + rsi + SEC_CEILH]
    mov     edx, [sectors + rsi + SEC_CEILPIC]
    mov     r8d, [sectors + rsi + SEC_LIGHT]
    call    R_FindPlane
    mov     [ceilingplane], rax
.ceildone:
    ; --- обход стен сектора ---
    xor     ebx, ebx
.lineloop:
    cmp     ebx, [sectors + rsi + SEC_LINECOUNT]
    jae     .linesdone
    mov     rdi, [sectors + rsi + SEC_LINES]
    mov     ecx, [rdi + rbx*4]
    mov     edx, r12d
    mov     r8d, r13d
    mov     r9d, r14d
    call    R_AddLine
    imul    esi, r12d, SECTOR_SIZE      ; R_AddLine мог затереть rsi
    inc     ebx
    jmp     .lineloop
.linesdone:
    dec     dword [portaldepth]
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
;  R_AddLine(ecx = линия, edx = сектор наблюдения, r8d = wx1, r9d = wx2)
; ---------------------------------------------------------------------------
R_AddLine:
    inc     dword [dbg_addline]
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 8

    imul    r12d, ecx, LINE_SIZE        ; смещение линии
    mov     [rw_lineofs], r12d
    mov     r13d, edx                   ; наш сектор
    mov     r14d, r8d                   ; wx1
    mov     r15d, r9d                   ; wx2

    ; --- ориентация: наш сектор должен быть справа от v1->v2 ---
    mov     eax, [lines + r12 + LN_FRONTSEC]
    cmp     eax, r13d
    jne     .flip
    mov     eax, [lines + r12 + LN_V1]
    mov     ecx, [lines + r12 + LN_V2]
    mov     edx, [lines + r12 + LN_SIDE0]
    mov     r8d, [lines + r12 + LN_BACKSEC]
    jmp     .oriented
.flip:
    mov     eax, [lines + r12 + LN_V2]
    mov     ecx, [lines + r12 + LN_V1]
    mov     edx, [lines + r12 + LN_SIDE1]
    mov     r8d, [lines + r12 + LN_FRONTSEC]
.oriented:
    imul    eax, VERTEX_SIZE
    mov     esi, [vertexes + rax + VX_X]
    mov     [rw_v1x], esi
    mov     esi, [vertexes + rax + VX_Y]
    mov     [rw_v1y], esi
    imul    ecx, VERTEX_SIZE
    mov     esi, [vertexes + rcx + VX_X]
    mov     [rw_v2x], esi
    mov     esi, [vertexes + rcx + VX_Y]
    mov     [rw_v2y], esi
    cmp     edx, -1
    je      .noside
    imul    edx, SIDE_SIZE
.noside:
    mov     [rw_sideofs], edx
    mov     [rw_frontsec], r13d
    mov     [rw_backsec], r8d

    ; --- углы концов ---
    mov     ecx, [rw_v1x]
    mov     edx, [rw_v1y]
    call    R_PointToAngle
    mov     ebx, eax                    ; angle1
    mov     ecx, [rw_v2x]
    mov     edx, [rw_v2y]
    call    R_PointToAngle
    mov     esi, eax                    ; angle2

    mov     edi, ebx
    sub     edi, esi                    ; span
    cmp     edi, ANG180
    jae     .done                       ; тыльная сторона

    mov     [rw_angle1], ebx
    sub     ebx, [viewangle]
    sub     esi, [viewangle]

    ; отсечение по левому краю
    mov     eax, ebx
    add     eax, [clipangle]            ; tspan
    mov     ecx, [clipangle]
    add     ecx, ecx
    cmp     eax, ecx
    jbe     .leftok
    sub     eax, ecx
    cmp     eax, edi
    jae     .done
    mov     ebx, [clipangle]
.leftok:
    ; отсечение по правому краю
    mov     eax, [clipangle]
    sub     eax, esi
    mov     ecx, [clipangle]
    add     ecx, ecx
    cmp     eax, ecx
    jbe     .rightok
    sub     eax, ecx
    cmp     eax, edi
    jae     .done
    mov     esi, [clipangle]
    neg     esi
.rightok:
    ; в экранные столбцы
    mov     eax, ebx
    add     eax, ANG90
    shr     eax, ANGLETOFINESHIFT
    and     eax, 0x0fff
    mov     ebx, [viewangletox + rax*4]
    mov     eax, esi
    add     eax, ANG90
    shr     eax, ANGLETOFINESHIFT
    and     eax, 0x0fff
    mov     esi, [viewangletox + rax*4]
    cmp     ebx, esi
    jge     .done                       ; ноль столбцов

    ; отсечение окном портала
    cmp     ebx, r14d
    jge     .s1
    mov     ebx, r14d
.s1:
    dec     esi                         ; последний столбец
    cmp     esi, r15d
    jle     .s2
    mov     esi, r15d
.s2:
    cmp     ebx, esi
    jg      .done

    ; --- рисуем стену ---
    or      dword [lines + r12 + LN_FLAGS], ML_MAPPED
    mov     ecx, ebx
    mov     edx, esi
    call    R_StoreWallRange

    ; --- рекурсия в соседний сектор ---
    mov     eax, [rw_backsec]
    cmp     eax, -1
    je      .done
    imul    ecx, eax, SECTOR_SIZE
    mov     edx, [sectors + rcx + SEC_CEILH]
    cmp     edx, [sectors + rcx + SEC_FLOORH]
    jle     .done                       ; закрыт
    imul    edx, r13d, SECTOR_SIZE
    mov     r8d, [sectors + rcx + SEC_CEILH]
    cmp     r8d, [sectors + rdx + SEC_FLOORH]
    jle     .done
    mov     r8d, [sectors + rcx + SEC_FLOORH]
    cmp     r8d, [sectors + rdx + SEC_CEILH]
    jge     .done
    ; плоскости текущего сектора нужно сохранить: рекурсия их переназначит
    push    qword [floorplane]
    push    qword [ceilingplane]
    mov     ecx, eax
    mov     edx, ebx
    mov     r8d, esi
    call    R_RenderSector
    pop     qword [ceilingplane]
    pop     qword [floorplane]
.done:
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_ScaleFromGlobalAngle(ecx = visangle) -> eax
; ---------------------------------------------------------------------------
R_ScaleFromGlobalAngle:
    push    rbx
    push    rsi
    mov     eax, ecx
    sub     eax, [viewangle]
    add     eax, ANG90
    shr     eax, ANGLETOFINESHIFT
    and     eax, FINEMASK
    mov     ebx, [finesine + rax*4]     ; sinea
    mov     eax, ecx
    sub     eax, [rw_normalangle]
    add     eax, ANG90
    shr     eax, ANGLETOFINESHIFT
    and     eax, FINEMASK
    mov     esi, [finesine + rax*4]     ; sineb
    mov     ecx, [projection]
    mov     edx, esi
    call    FixedMul
    mov     esi, eax                    ; num
    mov     ecx, [rw_distance]
    mov     edx, ebx
    call    FixedMul
    mov     ebx, eax                    ; den
    mov     eax, esi
    sar     eax, 16
    cmp     ebx, eax
    jle     .maxscale
    mov     ecx, esi
    mov     edx, ebx
    call    FixedDiv
    cmp     eax, 64*FRACUNIT
    jle     .chkmin
    mov     eax, 64*FRACUNIT
    jmp     .out
.chkmin:
    cmp     eax, 256
    jge     .out
    mov     eax, 256
    jmp     .out
.maxscale:
    mov     eax, 64*FRACUNIT
.out:
    pop     rsi
    pop     rbx
    ret
