; ===========================================================================
;  r_seg.asm -- отрисовка отрезка стены (аналог R_StoreWallRange DOOM)
; ===========================================================================

; ---------------------------------------------------------------------------
;  R_StoreWallRange(ecx = start, edx = stop)
; ---------------------------------------------------------------------------
R_StoreWallRange:
    inc     dword [dbg_walls]
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15

    mov     [rw_x], ecx
    mov     eax, edx
    inc     eax
    mov     [rw_stopx], eax
    mov     [rw_start], ecx

    ; --- drawseg ---
    mov     eax, [ds_index]
    cmp     eax, MAXDRAWSEGS-1
    jb      .dsok
    mov     eax, MAXDRAWSEGS-1
.dsok:
    imul    eax, DRAWSEG_SIZE
    lea     r15, [drawsegs]
    add     r15, rax                    ; r15 = текущий drawseg
    mov     eax, [rw_x]
    mov     [r15 + DS_X1], eax
    mov     [r15 + DS_X2], edx
    mov     eax, [rw_lineofs]
    mov     [r15 + DS_LINEOFS], eax
    mov     eax, [rw_sideofs]
    mov     [r15 + DS_SIDEOFS], eax
    mov     eax, [rw_frontsec]
    mov     [r15 + DS_FRONTSEC], eax
    mov     eax, [rw_backsec]
    mov     [r15 + DS_BACKSEC], eax
    mov     qword [r15 + DS_SPRTOPCLIP], 0
    mov     qword [r15 + DS_SPRBOTCLIP], 0
    mov     qword [r15 + DS_MASKEDCOL], 0
    mov     dword [r15 + DS_SILHOUETTE], 0

    ; --- нормаль стены и расстояние ---
    mov     ecx, [rw_v2x]
    sub     ecx, [rw_v1x]
    mov     edx, [rw_v2y]
    sub     edx, [rw_v1y]
    call    R_PointToAngleV
    add     eax, ANG90
    mov     [rw_normalangle], eax
    sub     eax, [rw_angle1]
    test    eax, eax
    jns     .absok
    neg     eax
.absok:
    cmp     eax, ANG90
    jbe     .offok
    mov     eax, ANG90
.offok:
    mov     ecx, ANG90
    sub     ecx, eax                    ; distangle
    shr     ecx, ANGLETOFINESHIFT
    and     ecx, FINEMASK
    mov     r12d, [finesine + rcx*4]
    mov     ecx, [rw_v1x]
    mov     edx, [rw_v1y]
    call    R_PointToDist
    mov     [rw_hyp], eax               ; hyp
    mov     ecx, eax
    mov     edx, r12d
    call    FixedMul
    mov     [rw_distance], eax

    ; --- масштаб на концах ---
    mov     eax, [rw_x]
    mov     ecx, [viewangle]
    add     ecx, [xtoviewangle + rax*4]
    call    R_ScaleFromGlobalAngle
    mov     [rw_scale], eax
    mov     [r15 + DS_SCALE1], eax
    mov     ecx, [rw_stopx]
    dec     ecx
    cmp     ecx, [rw_x]
    jle     .onecol
    mov     eax, ecx
    mov     ecx, [viewangle]
    add     ecx, [xtoviewangle + rax*4]
    call    R_ScaleFromGlobalAngle
    mov     [r15 + DS_SCALE2], eax
    sub     eax, [rw_scale]
    mov     ecx, [rw_stopx]
    dec     ecx
    sub     ecx, [rw_x]
    cdq
    idiv    ecx
    mov     [rw_scalestep], eax
    mov     [r15 + DS_SCALESTEP], eax
    jmp     .scaledone
.onecol:
    mov     eax, [rw_scale]
    mov     [r15 + DS_SCALE2], eax
    mov     dword [rw_scalestep], 0
    mov     dword [r15 + DS_SCALESTEP], 0
.scaledone:

    ; --- высоты ---
    imul    r12d, dword [rw_frontsec], SECTOR_SIZE
    mov     eax, [sectors + r12 + SEC_CEILH]
    sub     eax, [viewz]
    mov     [worldtop], eax
    mov     eax, [sectors + r12 + SEC_FLOORH]
    sub     eax, [viewz]
    mov     [worldbottom], eax
    mov     dword [midtexture], 0
    mov     dword [toptexture], 0
    mov     dword [bottomtexture], 0
    mov     dword [maskedtexture], 0

    mov     esi, [rw_sideofs]
    cmp     dword [rw_backsec], -1
    jne     .twosided

; ------------------------- односторонняя стена -----------------------------
    mov     eax, [sides + rsi + SD_MIDTEX]
    mov     [midtexture], eax
    mov     dword [markfloor], 1
    mov     dword [markceiling], 1
    mov     eax, [rw_lineofs]
    test    dword [lines + rax + LN_FLAGS], ML_DONTPEGBOTTOM
    jz      .sw_top
    mov     ecx, [midtexture]
    call    R_TexHeightFrac
    add     eax, [sectors + r12 + SEC_FLOORH]
    sub     eax, [viewz]
    mov     [rw_midtexturemid], eax
    jmp     .sw_peg
.sw_top:
    mov     eax, [worldtop]
    mov     [rw_midtexturemid], eax
.sw_peg:
    mov     eax, [sides + rsi + SD_ROWOFF]
    add     [rw_midtexturemid], eax
    mov     dword [r15 + DS_SILHOUETTE], SIL_BOTH
    lea     rax, [screenheightarray]
    mov     [r15 + DS_SPRTOPCLIP], rax
    lea     rax, [negonearray]
    mov     [r15 + DS_SPRBOTCLIP], rax
    mov     dword [r15 + DS_BSILHEIGHT], MAXINT
    mov     dword [r15 + DS_TSILHEIGHT], MININT
    jmp     .texsetup

; ------------------------- двусторонняя стена ------------------------------
.twosided:
    imul    r13d, dword [rw_backsec], SECTOR_SIZE
    mov     dword [r15 + DS_SILHOUETTE], 0
    ; силуэт снизу
    mov     eax, [sectors + r12 + SEC_FLOORH]
    cmp     eax, [sectors + r13 + SEC_FLOORH]
    jle     .sb1
    mov     dword [r15 + DS_SILHOUETTE], SIL_BOTTOM
    mov     [r15 + DS_BSILHEIGHT], eax
    jmp     .sb2
.sb1:
    mov     eax, [sectors + r13 + SEC_FLOORH]
    cmp     eax, [viewz]
    jle     .sb2
    mov     dword [r15 + DS_SILHOUETTE], SIL_BOTTOM
    mov     dword [r15 + DS_BSILHEIGHT], MAXINT
.sb2:
    ; силуэт сверху
    mov     eax, [sectors + r12 + SEC_CEILH]
    cmp     eax, [sectors + r13 + SEC_CEILH]
    jge     .st1
    or      dword [r15 + DS_SILHOUETTE], SIL_TOP
    mov     [r15 + DS_TSILHEIGHT], eax
    jmp     .st2
.st1:
    mov     eax, [sectors + r13 + SEC_CEILH]
    cmp     eax, [viewz]
    jge     .st2
    or      dword [r15 + DS_SILHOUETTE], SIL_TOP
    mov     dword [r15 + DS_TSILHEIGHT], MININT
.st2:
    mov     eax, [sectors + r13 + SEC_CEILH]
    cmp     eax, [sectors + r12 + SEC_FLOORH]
    jg      .st3
    lea     rax, [negonearray]
    mov     [r15 + DS_SPRBOTCLIP], rax
    mov     dword [r15 + DS_BSILHEIGHT], MAXINT
    or      dword [r15 + DS_SILHOUETTE], SIL_BOTTOM
.st3:
    mov     eax, [sectors + r13 + SEC_FLOORH]
    cmp     eax, [sectors + r12 + SEC_CEILH]
    jl      .st4
    lea     rax, [screenheightarray]
    mov     [r15 + DS_SPRTOPCLIP], rax
    mov     dword [r15 + DS_TSILHEIGHT], MININT
    or      dword [r15 + DS_SILHOUETTE], SIL_TOP
.st4:
    mov     eax, [sectors + r13 + SEC_CEILH]
    sub     eax, [viewz]
    mov     [worldhigh], eax
    mov     eax, [sectors + r13 + SEC_FLOORH]
    sub     eax, [viewz]
    mov     [worldlow], eax

    ; небо над обоими секторами -- потолок продолжается
    mov     eax, [sectors + r12 + SEC_CEILPIC]
    cmp     eax, [skyflatnum]
    jne     .nosky2
    mov     eax, [sectors + r13 + SEC_CEILPIC]
    cmp     eax, [skyflatnum]
    jne     .nosky2
    mov     eax, [worldhigh]
    mov     [worldtop], eax
.nosky2:
    ; нужно ли отмечать пол/потолок
    mov     dword [markfloor], 0
    mov     eax, [worldlow]
    cmp     eax, [worldbottom]
    jne     .mf
    mov     eax, [sectors + r13 + SEC_FLOORPIC]
    cmp     eax, [sectors + r12 + SEC_FLOORPIC]
    jne     .mf
    mov     eax, [sectors + r13 + SEC_LIGHT]
    cmp     eax, [sectors + r12 + SEC_LIGHT]
    je      .mfdone
.mf:
    mov     dword [markfloor], 1
.mfdone:
    mov     dword [markceiling], 0
    mov     eax, [worldhigh]
    cmp     eax, [worldtop]
    jne     .mc
    mov     eax, [sectors + r13 + SEC_CEILPIC]
    cmp     eax, [sectors + r12 + SEC_CEILPIC]
    jne     .mc
    mov     eax, [sectors + r13 + SEC_LIGHT]
    cmp     eax, [sectors + r12 + SEC_LIGHT]
    je      .mcdone
.mc:
    mov     dword [markceiling], 1
.mcdone:
    ; закрытый портал -- отмечаем обе плоскости
    mov     eax, [sectors + r13 + SEC_CEILH]
    cmp     eax, [sectors + r12 + SEC_FLOORH]
    jle     .closed
    mov     eax, [sectors + r13 + SEC_FLOORH]
    cmp     eax, [sectors + r12 + SEC_CEILH]
    jl      .notclosed
.closed:
    mov     dword [markceiling], 1
    mov     dword [markfloor], 1
.notclosed:

    ; верхняя текстура
    mov     eax, [worldhigh]
    cmp     eax, [worldtop]
    jge     .notop
    mov     eax, [sides + rsi + SD_TOPTEX]
    mov     [toptexture], eax
    mov     eax, [rw_lineofs]
    test    dword [lines + rax + LN_FLAGS], ML_DONTPEGTOP
    jz      .toppeg
    mov     eax, [worldtop]
    mov     [rw_toptexturemid], eax
    jmp     .notop
.toppeg:
    mov     ecx, [toptexture]
    call    R_TexHeightFrac
    add     eax, [sectors + r13 + SEC_CEILH]
    sub     eax, [viewz]
    mov     [rw_toptexturemid], eax
.notop:
    ; нижняя текстура
    mov     eax, [worldlow]
    cmp     eax, [worldbottom]
    jle     .nobot
    mov     eax, [sides + rsi + SD_BOTTEX]
    mov     [bottomtexture], eax
    mov     eax, [rw_lineofs]
    test    dword [lines + rax + LN_FLAGS], ML_DONTPEGBOTTOM
    jz      .botlow
    mov     eax, [worldtop]
    mov     [rw_bottomtexturemid], eax
    jmp     .nobot
.botlow:
    mov     eax, [worldlow]
    mov     [rw_bottomtexturemid], eax
.nobot:
    mov     eax, [sides + rsi + SD_ROWOFF]
    add     [rw_toptexturemid], eax
    add     [rw_bottomtexturemid], eax
    ; средняя (полупрозрачная) текстура
    mov     eax, [sides + rsi + SD_MIDTEX]
    test    eax, eax
    jz      .texsetup
    mov     eax, [rw_stopx]
    sub     eax, [rw_start]
    add     eax, [lastopening]
    cmp     eax, MAXOPENINGS
    ja      .texsetup                   ; нет места -- без маскированной текстуры
    mov     dword [maskedtexture], 1
    mov     eax, [lastopening]
    lea     rdx, [openings]
    lea     rdx, [rdx + rax*4]
    mov     eax, [rw_start]
    shl     eax, 2
    sub     rdx, rax
    mov     [r15 + DS_MASKEDCOL], rdx
    mov     [maskedtexturecol], rdx
    mov     eax, [rw_stopx]
    sub     eax, [rw_start]
    add     [lastopening], eax

; ------------------------- общие параметры текстуры ------------------------
.texsetup:
    mov     eax, [midtexture]
    or      eax, [toptexture]
    or      eax, [bottomtexture]
    or      eax, [maskedtexture]
    mov     [segtextured], eax
    test    eax, eax
    jz      .nosegtex

    mov     eax, [rw_normalangle]
    sub     eax, [rw_angle1]
    mov     edi, eax                    ; сохранить знак
    cmp     eax, ANG180
    jbe     .oa1
    neg     eax
.oa1:
    cmp     eax, ANG90
    jbe     .oa2
    mov     eax, ANG90
.oa2:
    shr     eax, ANGLETOFINESHIFT
    and     eax, FINEMASK
    mov     edx, [finesine + rax*4]
    mov     ecx, [rw_hyp]
    call    FixedMul
    cmp     edi, ANG180
    jae     .nonegoff
    neg     eax
.nonegoff:
    add     eax, [sides + rsi + SD_TEXOFF]
    mov     [rw_offset], eax
    mov     eax, ANG90
    add     eax, [viewangle]
    sub     eax, [rw_normalangle]
    mov     [rw_centerangle], eax

    ; освещение стены
    mov     rax, [fixedcolormap]
    test    rax, rax
    jnz     .nosegtex
    mov     eax, [sectors + r12 + SEC_LIGHT]
    sar     eax, LIGHTSEGSHIFT
    add     eax, [extralight]
    ; горизонтальные стены темнее, вертикальные светлее
    mov     ecx, [rw_v1y]
    cmp     ecx, [rw_v2y]
    jne     .nl1
    dec     eax
    jmp     .nl2
.nl1:
    mov     ecx, [rw_v1x]
    cmp     ecx, [rw_v2x]
    jne     .nl2
    inc     eax
.nl2:
    test    eax, eax
    jns     .nl3
    xor     eax, eax
.nl3:
    cmp     eax, LIGHTLEVELS
    jl      .nl4
    mov     eax, LIGHTLEVELS-1
.nl4:
    imul    eax, MAXLIGHTSCALE*8
    lea     rdx, [scalelight]
    add     rdx, rax
    mov     [walllights], rdx
.nosegtex:

    ; плоскости вне поля зрения не отмечаем
    imul    r12d, dword [rw_frontsec], SECTOR_SIZE
    mov     eax, [sectors + r12 + SEC_FLOORH]
    cmp     eax, [viewz]
    jl      .mf2
    mov     dword [markfloor], 0
.mf2:
    mov     eax, [sectors + r12 + SEC_CEILH]
    cmp     eax, [viewz]
    jg      .mc2
    mov     eax, [sectors + r12 + SEC_CEILPIC]
    cmp     eax, [skyflatnum]
    je      .mc2
    mov     dword [markceiling], 0
.mc2:

    ; --- шаги по вертикали ---
    sar     dword [worldtop], 4
    sar     dword [worldbottom], 4
    mov     ecx, [rw_scalestep]
    mov     edx, [worldtop]
    call    FixedMul
    neg     eax
    mov     [topstep], eax
    mov     ecx, [worldtop]
    mov     edx, [rw_scale]
    call    FixedMul
    mov     ecx, [centeryfrac]
    sar     ecx, 4
    sub     ecx, eax
    mov     [topfrac], ecx
    mov     ecx, [rw_scalestep]
    mov     edx, [worldbottom]
    call    FixedMul
    neg     eax
    mov     [bottomstep], eax
    mov     ecx, [worldbottom]
    mov     edx, [rw_scale]
    call    FixedMul
    mov     ecx, [centeryfrac]
    sar     ecx, 4
    sub     ecx, eax
    mov     [bottomfrac], ecx

    cmp     dword [rw_backsec], -1
    je      .nosteps
    sar     dword [worldhigh], 4
    sar     dword [worldlow], 4
    mov     eax, [worldhigh]
    cmp     eax, [worldtop]
    jge     .nohigh
    mov     ecx, eax
    mov     edx, [rw_scale]
    call    FixedMul
    mov     ecx, [centeryfrac]
    sar     ecx, 4
    sub     ecx, eax
    mov     [pixhigh], ecx
    mov     ecx, [rw_scalestep]
    mov     edx, [worldhigh]
    call    FixedMul
    neg     eax
    mov     [pixhighstep], eax
.nohigh:
    mov     eax, [worldlow]
    cmp     eax, [worldbottom]
    jle     .nolow
    mov     ecx, eax
    mov     edx, [rw_scale]
    call    FixedMul
    mov     ecx, [centeryfrac]
    sar     ecx, 4
    sub     ecx, eax
    mov     [pixlow], ecx
    mov     ecx, [rw_scalestep]
    mov     edx, [worldlow]
    call    FixedMul
    neg     eax
    mov     [pixlowstep], eax
.nolow:
.nosteps:

    ; --- закрепление визплейнов ---
    cmp     dword [markceiling], 0
    je      .nomc
    mov     rcx, [ceilingplane]
    test    rcx, rcx
    jz      .nomc
    mov     edx, [rw_x]
    mov     r8d, [rw_stopx]
    dec     r8d
    call    R_CheckPlane
    mov     [ceilingplane], rax
.nomc:
    cmp     dword [markfloor], 0
    je      .nomf
    mov     rcx, [floorplane]
    test    rcx, rcx
    jz      .nomf
    mov     edx, [rw_x]
    mov     r8d, [rw_stopx]
    dec     r8d
    call    R_CheckPlane
    mov     [floorplane], rax
.nomf:

    call    R_RenderSegLoop

    ; --- сохранение силуэтов для спрайтов ---
    mov     eax, [r15 + DS_SILHOUETTE]
    and     eax, SIL_TOP
    jnz     .needtop
    cmp     dword [maskedtexture], 0
    je      .notop2
.needtop:
    cmp     qword [r15 + DS_SPRTOPCLIP], 0
    jne     .notop2
    mov     eax, [rw_stopx]
    sub     eax, [rw_start]
    add     eax, [lastopening]
    cmp     eax, MAXOPENINGS
    jbe     .topspace
    lea     rax, [screenheightarray]    ; переполнение -- считаем стену глухой
    mov     [r15 + DS_SPRTOPCLIP], rax
    jmp     .notop2
.topspace:
    mov     eax, [lastopening]
    lea     rdi, [openings]
    lea     rdi, [rdi + rax*4]
    mov     esi, [rw_start]
    mov     ecx, [rw_stopx]
    sub     ecx, esi
    push    rcx
    lea     rdx, [ceilingclip]
    lea     rdx, [rdx + rsi*4]
.cptop:
    mov     eax, [rdx]
    mov     [rdi], eax
    add     rdx, 4
    add     rdi, 4
    dec     ecx
    jnz     .cptop
    pop     rcx
    mov     eax, [lastopening]
    lea     rdi, [openings]
    lea     rdi, [rdi + rax*4]
    mov     eax, [rw_start]
    shl     eax, 2
    sub     rdi, rax
    mov     [r15 + DS_SPRTOPCLIP], rdi
    add     [lastopening], ecx
.notop2:
    mov     eax, [r15 + DS_SILHOUETTE]
    and     eax, SIL_BOTTOM
    jnz     .needbot
    cmp     dword [maskedtexture], 0
    je      .nobot2
.needbot:
    cmp     qword [r15 + DS_SPRBOTCLIP], 0
    jne     .nobot2
    mov     eax, [rw_stopx]
    sub     eax, [rw_start]
    add     eax, [lastopening]
    cmp     eax, MAXOPENINGS
    jbe     .botspace
    lea     rax, [negonearray]
    mov     [r15 + DS_SPRBOTCLIP], rax
    jmp     .nobot2
.botspace:
    mov     eax, [lastopening]
    lea     rdi, [openings]
    lea     rdi, [rdi + rax*4]
    mov     esi, [rw_start]
    mov     ecx, [rw_stopx]
    sub     ecx, esi
    push    rcx
    lea     rdx, [floorclip]
    lea     rdx, [rdx + rsi*4]
.cpbot:
    mov     eax, [rdx]
    mov     [rdi], eax
    add     rdx, 4
    add     rdi, 4
    dec     ecx
    jnz     .cpbot
    pop     rcx
    mov     eax, [lastopening]
    lea     rdi, [openings]
    lea     rdi, [rdi + rax*4]
    mov     eax, [rw_start]
    shl     eax, 2
    sub     rdi, rax
    mov     [r15 + DS_SPRBOTCLIP], rdi
    add     [lastopening], ecx
.nobot2:
    cmp     dword [maskedtexture], 0
    je      .nomask
    mov     eax, [r15 + DS_SILHOUETTE]
    test    eax, SIL_TOP
    jnz     .mk1
    or      dword [r15 + DS_SILHOUETTE], SIL_TOP
    mov     dword [r15 + DS_TSILHEIGHT], MININT
.mk1:
    mov     eax, [r15 + DS_SILHOUETTE]
    test    eax, SIL_BOTTOM
    jnz     .nomask
    or      dword [r15 + DS_SILHOUETTE], SIL_BOTTOM
    mov     dword [r15 + DS_BSILHEIGHT], MAXINT
.nomask:
    mov     eax, [rw_midtexturemid]
    mov     [r15 + DS_TEXMID], eax
    mov     rax, [walllights]
    mov     [r15 + DS_LIGHTS], rax
    cmp     dword [ds_index], MAXDRAWSEGS-1
    jae     .noinc
    inc     dword [ds_index]
.noinc:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_RenderSegLoop
; ---------------------------------------------------------------------------
R_RenderSegLoop:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15

.xloop:
    mov     ebx, [rw_x]
    cmp     ebx, [rw_stopx]
    jae     .xdone

    ; yl
    mov     eax, [topfrac]
    add     eax, HEIGHTUNIT-1
    sar     eax, HEIGHTBITS
    mov     r12d, eax                   ; yl
    mov     eax, [ceilingclip + rbx*4]
    inc     eax
    cmp     r12d, eax
    jge     .yl_ok
    mov     r12d, eax
.yl_ok:
    cmp     dword [markceiling], 0
    je      .nomarkc
    mov     eax, [ceilingclip + rbx*4]
    inc     eax
    mov     r8d, eax                    ; top
    mov     eax, r12d
    dec     eax                         ; bottom
    mov     ecx, [floorclip + rbx*4]
    dec     ecx
    cmp     eax, ecx
    jle     .cb_ok
    mov     eax, ecx
.cb_ok:
    cmp     r8d, eax
    jg      .nomarkc
    mov     rdx, [ceilingplane]
    test    rdx, rdx
    jz      .nomarkc
    lea     rcx, [rdx + VP_TOP + 1]
    mov     [rcx + rbx], r8b
    lea     rcx, [rdx + VP_BOTTOM + 1]
    mov     [rcx + rbx], al
.nomarkc:

    ; yh
    mov     eax, [bottomfrac]
    sar     eax, HEIGHTBITS
    mov     r13d, eax                   ; yh
    mov     eax, [floorclip + rbx*4]
    dec     eax
    cmp     r13d, eax
    jle     .yh_ok
    mov     r13d, eax
.yh_ok:
    cmp     dword [markfloor], 0
    je      .nomarkf
    mov     r8d, r13d
    inc     r8d                         ; top
    mov     eax, [floorclip + rbx*4]
    dec     eax                         ; bottom
    mov     ecx, [ceilingclip + rbx*4]
    inc     ecx
    cmp     r8d, ecx
    jg      .ft_ok
    mov     r8d, ecx
.ft_ok:
    cmp     r8d, eax
    jg      .nomarkf
    mov     rdx, [floorplane]
    test    rdx, rdx
    jz      .nomarkf
    lea     rcx, [rdx + VP_TOP + 1]
    mov     [rcx + rbx], r8b
    lea     rcx, [rdx + VP_BOTTOM + 1]
    mov     [rcx + rbx], al
.nomarkf:

    ; --- столбец текстуры и освещение ---
    cmp     dword [segtextured], 0
    je      .notex
    mov     eax, [rw_centerangle]
    add     eax, [xtoviewangle + rbx*4]
    shr     eax, ANGLETOFINESHIFT
    and     eax, 0x0fff
    mov     ecx, [finetangent + rax*4]
    mov     edx, [rw_distance]
    call    FixedMul
    mov     ecx, [rw_offset]
    sub     ecx, eax
    sar     ecx, FRACBITS
    mov     r14d, ecx                   ; texturecolumn
    mov     eax, [rw_scale]
    sar     eax, LIGHTSCALESHIFT
    cmp     eax, MAXLIGHTSCALE
    jb      .li_ok
    mov     eax, MAXLIGHTSCALE-1
.li_ok:
    mov     rdx, [fixedcolormap]
    test    rdx, rdx
    jnz     .fixedcm
    mov     rdx, [walllights]
    mov     rdx, [rdx + rax*8]
.fixedcm:
    mov     [dc_colormap], rdx
    mov     [dc_x], ebx
    mov     eax, 0xffffffff
    xor     edx, edx
    div     dword [rw_scale]
    mov     [dc_iscale], eax
.notex:

    ; --- ярусы ---
    cmp     dword [midtexture], 0
    je      .tiers
    mov     [dc_yl], r12d
    mov     [dc_yh], r13d
    mov     eax, [rw_midtexturemid]
    mov     [dc_texturemid], eax
    mov     ecx, [midtexture]
    mov     edx, r14d
    call    R_GetColumn
    mov     [dc_source], rax
    mov     ecx, [midtexture]
    call    R_TexHeightMask
    mov     [dc_texmask], eax
    call    R_DrawColumn
    mov     eax, [viewheight]
    mov     [ceilingclip + rbx*4], eax
    mov     dword [floorclip + rbx*4], -1
    jmp     .colnext

.tiers:
    cmp     dword [toptexture], 0
    je      .notoptex
    mov     eax, [pixhigh]
    sar     eax, HEIGHTBITS
    mov     r15d, eax                   ; mid
    mov     eax, [pixhighstep]
    add     [pixhigh], eax
    mov     eax, [floorclip + rbx*4]
    dec     eax
    cmp     r15d, eax
    jle     .tt1
    mov     r15d, eax
.tt1:
    cmp     r15d, r12d
    jl      .tt2
    mov     [dc_yl], r12d
    mov     [dc_yh], r15d
    mov     eax, [rw_toptexturemid]
    mov     [dc_texturemid], eax
    mov     ecx, [toptexture]
    mov     edx, r14d
    call    R_GetColumn
    mov     [dc_source], rax
    mov     ecx, [toptexture]
    call    R_TexHeightMask
    mov     [dc_texmask], eax
    call    R_DrawColumn
    mov     [ceilingclip + rbx*4], r15d
    jmp     .aftertop
.tt2:
    mov     eax, r12d
    dec     eax
    mov     [ceilingclip + rbx*4], eax
    jmp     .aftertop
.notoptex:
    cmp     dword [markceiling], 0
    je      .aftertop
    mov     eax, r12d
    dec     eax
    mov     [ceilingclip + rbx*4], eax
.aftertop:

    cmp     dword [bottomtexture], 0
    je      .nobottex
    mov     eax, [pixlow]
    add     eax, HEIGHTUNIT-1
    sar     eax, HEIGHTBITS
    mov     r15d, eax
    mov     eax, [pixlowstep]
    add     [pixlow], eax
    mov     eax, [ceilingclip + rbx*4]
    inc     eax
    cmp     r15d, eax
    jge     .bb1
    mov     r15d, eax
.bb1:
    cmp     r15d, r13d
    jg      .bb2
    mov     [dc_yl], r15d
    mov     [dc_yh], r13d
    mov     eax, [rw_bottomtexturemid]
    mov     [dc_texturemid], eax
    mov     ecx, [bottomtexture]
    mov     edx, r14d
    call    R_GetColumn
    mov     [dc_source], rax
    mov     ecx, [bottomtexture]
    call    R_TexHeightMask
    mov     [dc_texmask], eax
    call    R_DrawColumn
    mov     [floorclip + rbx*4], r15d
    jmp     .afterbot
.bb2:
    mov     eax, r13d
    inc     eax
    mov     [floorclip + rbx*4], eax
    jmp     .afterbot
.nobottex:
    cmp     dword [markfloor], 0
    je      .afterbot
    mov     eax, r13d
    inc     eax
    mov     [floorclip + rbx*4], eax
.afterbot:

    cmp     dword [maskedtexture], 0
    je      .colnext
    mov     rdx, [maskedtexturecol]
    mov     [rdx + rbx*4], r14d

.colnext:
    mov     eax, [rw_scalestep]
    add     [rw_scale], eax
    mov     eax, [topstep]
    add     [topfrac], eax
    mov     eax, [bottomstep]
    add     [bottomfrac], eax
    inc     dword [rw_x]
    jmp     .xloop
.xdone:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
