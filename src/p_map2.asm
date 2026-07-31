; ===========================================================================
;  p_map2.asm -- скольжение вдоль стен, стрельба, использование линий,
;                проверка видимости, взрывы
; ===========================================================================


; ---------------------------------------------------------------------------
;  P_Random -> eax (0..255),  P_SubRandom -> eax (-255..255)
; ---------------------------------------------------------------------------
P_Random:
    mov     eax, [prndseed]
    imul    eax, 1103515245
    add     eax, 12345
    mov     [prndseed], eax
    shr     eax, 16
    and     eax, 255
    ret

P_SubRandom:
    push    rbx
    call    P_Random
    mov     ebx, eax
    call    P_Random
    sub     ebx, eax
    mov     eax, ebx
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_SlideMove(rcx = mobj)
; ---------------------------------------------------------------------------
P_SlideMove:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    mov     rbx, rcx
    mov     [slidemo], rbx
    xor     r13d, r13d                  ; hitcount
.retry:
    inc     r13d
    cmp     r13d, 3
    jae     .stairstep

    ; ведущие углы
    mov     eax, [rbx + MO_X]
    mov     ecx, [rbx + MO_RADIUS]
    cmp     dword [rbx + MO_MOMX], 0
    jle     .lx1
    add     eax, ecx
    mov     edx, [rbx + MO_X]
    sub     edx, ecx
    jmp     .lx2
.lx1:
    sub     eax, ecx
    mov     edx, [rbx + MO_X]
    add     edx, ecx
.lx2:
    mov     [sl_leadx], eax
    mov     [sl_trailx], edx
    mov     eax, [rbx + MO_Y]
    cmp     dword [rbx + MO_MOMY], 0
    jle     .ly1
    add     eax, ecx
    mov     edx, [rbx + MO_Y]
    sub     edx, ecx
    jmp     .ly2
.ly1:
    sub     eax, ecx
    mov     edx, [rbx + MO_Y]
    add     edx, ecx
.ly2:
    mov     [sl_leady], eax
    mov     [sl_traily], edx

    mov     dword [bestslidefrac], FRACUNIT+1

    ; три трассы
    mov     eax, [sl_leadx]
    mov     [pt_x1], eax
    add     eax, [rbx + MO_MOMX]
    mov     [pt_x2], eax
    mov     eax, [sl_leady]
    mov     [pt_y1], eax
    add     eax, [rbx + MO_MOMY]
    mov     [pt_y2], eax
    mov     ecx, PT_ADDLINES
    mov     rdx, PTR_SlideTraverse
    call    P_PathTraverse

    mov     eax, [sl_trailx]
    mov     [pt_x1], eax
    add     eax, [rbx + MO_MOMX]
    mov     [pt_x2], eax
    mov     eax, [sl_leady]
    mov     [pt_y1], eax
    add     eax, [rbx + MO_MOMY]
    mov     [pt_y2], eax
    mov     ecx, PT_ADDLINES
    mov     rdx, PTR_SlideTraverse
    call    P_PathTraverse

    mov     eax, [sl_leadx]
    mov     [pt_x1], eax
    add     eax, [rbx + MO_MOMX]
    mov     [pt_x2], eax
    mov     eax, [sl_traily]
    mov     [pt_y1], eax
    add     eax, [rbx + MO_MOMY]
    mov     [pt_y2], eax
    mov     ecx, PT_ADDLINES
    mov     rdx, PTR_SlideTraverse
    call    P_PathTraverse

    cmp     dword [bestslidefrac], FRACUNIT+1
    je      .stairstep

    ; подвинуться вплотную к стене
    mov     eax, [bestslidefrac]
    sub     eax, 0x800
    mov     [bestslidefrac], eax
    cmp     eax, 0
    jle     .noapproach
    mov     ecx, [rbx + MO_MOMX]
    mov     edx, eax
    call    FixedMul
    mov     esi, eax
    mov     ecx, [rbx + MO_MOMY]
    mov     edx, [bestslidefrac]
    call    FixedMul
    mov     edi, eax
    mov     rcx, rbx
    mov     edx, [rbx + MO_X]
    add     edx, esi
    mov     r8d, [rbx + MO_Y]
    add     r8d, edi
    call    P_TryMove
    test    eax, eax
    jz      .stairstep
.noapproach:
    mov     eax, FRACUNIT
    mov     ecx, [bestslidefrac]
    add     ecx, 0x800
    sub     eax, ecx
    cmp     eax, FRACUNIT
    jle     .cl1
    mov     eax, FRACUNIT
.cl1:
    mov     [bestslidefrac], eax
    cmp     eax, 0
    jle     .done
    mov     ecx, [rbx + MO_MOMX]
    mov     edx, eax
    call    FixedMul
    mov     [tmxmove], eax
    mov     ecx, [rbx + MO_MOMY]
    mov     edx, [bestslidefrac]
    call    FixedMul
    mov     [tmymove], eax
    mov     r8d, [bestslideline]
    call    P_HitSlideLine
    mov     eax, [tmxmove]
    mov     [rbx + MO_MOMX], eax
    mov     eax, [tmymove]
    mov     [rbx + MO_MOMY], eax
    mov     rcx, rbx
    mov     edx, [rbx + MO_X]
    add     edx, [tmxmove]
    mov     r8d, [rbx + MO_Y]
    add     r8d, [tmymove]
    call    P_TryMove
    test    eax, eax
    jnz     .done
    jmp     .retry

.stairstep:
    mov     rcx, rbx
    mov     edx, [rbx + MO_X]
    mov     r8d, [rbx + MO_Y]
    add     r8d, [rbx + MO_MOMY]
    call    P_TryMove
    test    eax, eax
    jnz     .done
    mov     rcx, rbx
    mov     edx, [rbx + MO_X]
    add     edx, [rbx + MO_MOMX]
    mov     r8d, [rbx + MO_Y]
    call    P_TryMove
.done:
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; PTR_SlideTraverse(rcx = intercept)
PTR_SlideTraverse:
    push    rbx
    push    rsi
    mov     rbx, rcx
    cmp     dword [rbx + IC_ISALINE], 0
    je      .cont
    mov     esi, [rbx + IC_PTR]         ; смещение линии
    test    dword [lines + rsi + LN_FLAGS], ML_TWOSIDED
    jnz     .twosided
    mov     rdx, [slidemo]
    mov     ecx, [rdx + MO_X]
    mov     r8d, esi
    mov     edx, [rdx + MO_Y]
    call    P_PointOnLineSide
    test    eax, eax
    jnz     .cont                       ; тыльная сторона -- пропускаем
    jmp     .blocking
.twosided:
    mov     r8d, esi
    call    P_LineOpening
    mov     rdx, [slidemo]
    mov     eax, [openrange]
    cmp     eax, [rdx + MO_HEIGHT]
    jl      .blocking
    mov     eax, [opentop]
    sub     eax, [rdx + MO_Z]
    cmp     eax, [rdx + MO_HEIGHT]
    jl      .blocking
    mov     eax, [openbottom]
    sub     eax, [rdx + MO_Z]
    cmp     eax, 24*FRACUNIT
    jg      .blocking
.cont:
    mov     eax, 1
    pop     rsi
    pop     rbx
    ret
.blocking:
    mov     eax, [rbx + IC_FRAC]
    cmp     eax, [bestslidefrac]
    jge     .noblock
    mov     ecx, [bestslidefrac]
    mov     [secondslidefrac], ecx
    mov     ecx, [bestslideline]
    mov     [secondslideline], ecx
    mov     [bestslidefrac], eax
    mov     [bestslideline], esi
.noblock:
    xor     eax, eax
    pop     rsi
    pop     rbx
    ret

; P_HitSlideLine(r8d = смещение линии)
P_HitSlideLine:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    mov     r12d, r8d
    mov     eax, [lines + r12 + LN_SLOPETYPE]
    cmp     eax, ST_HORIZONTAL
    jne     .nothoriz
    mov     dword [tmymove], 0
    jmp     .done
.nothoriz:
    cmp     eax, ST_VERTICAL
    jne     .slope
    mov     dword [tmxmove], 0
    jmp     .done
.slope:
    mov     rdx, [slidemo]
    mov     ecx, [rdx + MO_X]
    mov     r8d, r12d
    mov     edx, [rdx + MO_Y]
    call    P_PointOnLineSide
    mov     edi, eax                    ; side
    mov     ecx, [lines + r12 + LN_DX]
    mov     edx, [lines + r12 + LN_DY]
    call    R_PointToAngleV
    mov     ebx, eax                    ; lineangle
    cmp     edi, 1
    jne     .noflip
    add     ebx, ANG180
.noflip:
    mov     ecx, [tmxmove]
    mov     edx, [tmymove]
    call    R_PointToAngleV
    sub     eax, ebx                    ; deltaangle
    cmp     eax, ANG180
    jbe     .nodelta
    add     eax, ANG180
.nodelta:
    shr     eax, ANGLETOFINESHIFT
    and     eax, FINEMASK
    mov     esi, eax                    ; deltaangle index
    shr     ebx, ANGLETOFINESHIFT
    and     ebx, FINEMASK               ; lineangle index
    mov     ecx, [tmxmove]
    mov     edx, [tmymove]
    call    P_AproxDistance
    mov     ecx, eax
    mov     edx, [finecosine + rsi*4]
    call    FixedMul
    mov     edi, eax                    ; newlen
    mov     ecx, edi
    mov     edx, [finecosine + rbx*4]
    call    FixedMul
    mov     [tmxmove], eax
    mov     ecx, edi
    mov     edx, [finesine + rbx*4]
    call    FixedMul
    mov     [tmymove], eax
.done:
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_AimLineAttack(rcx = стрелок, edx = угол, r8d = дистанция) -> eax = наклон
; ---------------------------------------------------------------------------
P_AimLineAttack:
    push    rbx
    push    rsi
    push    rdi
    mov     rbx, rcx
    mov     [shootthing], rbx
    mov     [attackrange], r8d
    mov     esi, edx
    shr     esi, ANGLETOFINESHIFT
    and     esi, FINEMASK
    mov     eax, r8d
    sar     eax, FRACBITS
    mov     edi, eax
    imul    eax, [finecosine + rsi*4]
    add     eax, [rbx + MO_X]
    mov     [pt_x2], eax
    mov     eax, edi
    imul    eax, [finesine + rsi*4]
    add     eax, [rbx + MO_Y]
    mov     [pt_y2], eax
    mov     eax, [rbx + MO_X]
    mov     [pt_x1], eax
    mov     eax, [rbx + MO_Y]
    mov     [pt_y1], eax
    mov     eax, [rbx + MO_Z]
    mov     ecx, [rbx + MO_HEIGHT]
    sar     ecx, 1
    add     eax, ecx
    add     eax, 8*FRACUNIT
    mov     [shootz], eax
    mov     dword [topslope], (100*FRACUNIT)/160
    mov     dword [bottomslope], -((100*FRACUNIT)/160)
    mov     qword [linetarget], 0
    mov     ecx, PT_ADDLINES|PT_ADDTHINGS
    mov     rdx, PTR_AimTraverse
    call    P_PathTraverse
    cmp     qword [linetarget], 0
    je      .none
    mov     eax, [aimslope]
    jmp     .out
.none:
    xor     eax, eax
.out:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; PTR_AimTraverse(rcx = intercept)
PTR_AimTraverse:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    mov     rbx, rcx
    cmp     dword [rbx + IC_ISALINE], 0
    je      .thing
    mov     esi, [rbx + IC_PTR]
    test    dword [lines + rsi + LN_FLAGS], ML_TWOSIDED
    jz      .stop
    mov     r8d, esi
    call    P_LineOpening
    mov     eax, [openbottom]
    cmp     eax, [opentop]
    jge     .stop
    mov     ecx, [attackrange]
    mov     edx, [rbx + IC_FRAC]
    call    FixedMul
    mov     r12d, eax                   ; dist
    test    r12d, r12d
    jz      .stop
    mov     eax, [lines + rsi + LN_FRONTSEC]
    imul    eax, SECTOR_SIZE
    mov     edx, [lines + rsi + LN_BACKSEC]
    imul    edx, SECTOR_SIZE
    mov     ecx, [sectors + rax + SEC_FLOORH]
    cmp     ecx, [sectors + rdx + SEC_FLOORH]
    je      .nofloor
    mov     ecx, [openbottom]
    sub     ecx, [shootz]
    mov     edx, r12d
    call    FixedDiv
    cmp     eax, [bottomslope]
    jle     .nofloor
    mov     [bottomslope], eax
.nofloor:
    mov     eax, [lines + rsi + LN_FRONTSEC]
    imul    eax, SECTOR_SIZE
    mov     edx, [lines + rsi + LN_BACKSEC]
    imul    edx, SECTOR_SIZE
    mov     ecx, [sectors + rax + SEC_CEILH]
    cmp     ecx, [sectors + rdx + SEC_CEILH]
    je      .noceil
    mov     ecx, [opentop]
    sub     ecx, [shootz]
    mov     edx, r12d
    call    FixedDiv
    cmp     eax, [topslope]
    jge     .noceil
    mov     [topslope], eax
.noceil:
    mov     eax, [topslope]
    cmp     eax, [bottomslope]
    jle     .stop
    mov     eax, 1
    jmp     .out

.thing:
    mov     rsi, [rbx + IC_PTR]
    cmp     rsi, [shootthing]
    je      .cont
    test    dword [rsi + MO_FLAGS], MF_SHOOTABLE
    jz      .cont
    mov     ecx, [attackrange]
    mov     edx, [rbx + IC_FRAC]
    call    FixedMul
    mov     r12d, eax
    test    r12d, r12d
    jz      .cont
    mov     ecx, [rsi + MO_Z]
    add     ecx, [rsi + MO_HEIGHT]
    sub     ecx, [shootz]
    mov     edx, r12d
    call    FixedDiv
    mov     edi, eax                    ; thingtopslope
    cmp     edi, [bottomslope]
    jl      .cont
    mov     ecx, [rsi + MO_Z]
    sub     ecx, [shootz]
    mov     edx, r12d
    call    FixedDiv                    ; thingbottomslope
    cmp     eax, [topslope]
    jg      .cont
    cmp     edi, [topslope]
    jle     .t1
    mov     edi, [topslope]
.t1:
    cmp     eax, [bottomslope]
    jge     .t2
    mov     eax, [bottomslope]
.t2:
    add     eax, edi
    sar     eax, 1
    mov     [aimslope], eax
    mov     [linetarget], rsi
    jmp     .stop
.cont:
    mov     eax, 1
    jmp     .out
.stop:
    xor     eax, eax
.out:
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_LineAttack(rcx=стрелок, edx=угол, r8d=дистанция, r9d=наклон, [la_damage])
; ---------------------------------------------------------------------------
P_LineAttack:
    push    rbx
    push    rsi
    push    rdi
    mov     rbx, rcx
    mov     [shootthing], rbx
    mov     [attackrange], r8d
    mov     [aimslope], r9d
    mov     esi, edx
    shr     esi, ANGLETOFINESHIFT
    and     esi, FINEMASK
    mov     eax, r8d
    sar     eax, FRACBITS
    mov     edi, eax
    imul    eax, [finecosine + rsi*4]
    add     eax, [rbx + MO_X]
    mov     [pt_x2], eax
    mov     eax, edi
    imul    eax, [finesine + rsi*4]
    add     eax, [rbx + MO_Y]
    mov     [pt_y2], eax
    mov     eax, [rbx + MO_X]
    mov     [pt_x1], eax
    mov     eax, [rbx + MO_Y]
    mov     [pt_y1], eax
    mov     eax, [rbx + MO_Z]
    mov     ecx, [rbx + MO_HEIGHT]
    sar     ecx, 1
    add     eax, ecx
    add     eax, 8*FRACUNIT
    mov     [shootz], eax
    mov     ecx, PT_ADDLINES|PT_ADDTHINGS
    mov     rdx, PTR_ShootTraverse
    call    P_PathTraverse
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; PTR_ShootTraverse(rcx = intercept)
PTR_ShootTraverse:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    mov     rbx, rcx
    cmp     dword [rbx + IC_ISALINE], 0
    je      .thing

    mov     esi, [rbx + IC_PTR]
    ; специальная линия (стрелковый переключатель)
    cmp     dword [lines + rsi + LN_SPECIAL], 0
    je      .nospec
    mov     rcx, [shootthing]
    mov     edx, esi
    call    P_ShootSpecialLine
.nospec:
    test    dword [lines + rsi + LN_FLAGS], ML_TWOSIDED
    jz      .hitwall
    mov     r8d, esi
    call    P_LineOpening
    mov     ecx, [attackrange]
    mov     edx, [rbx + IC_FRAC]
    call    FixedMul
    mov     r12d, eax                   ; dist
    test    r12d, r12d
    jnz     .distok
    mov     r12d, 1
.distok:
    mov     eax, [lines + rsi + LN_FRONTSEC]
    imul    eax, SECTOR_SIZE
    mov     edx, [lines + rsi + LN_BACKSEC]
    imul    edx, SECTOR_SIZE
    mov     ecx, [sectors + rax + SEC_FLOORH]
    cmp     ecx, [sectors + rdx + SEC_FLOORH]
    je      .nof
    mov     ecx, [openbottom]
    sub     ecx, [shootz]
    mov     edx, r12d
    call    FixedDiv
    cmp     eax, [aimslope]
    jg      .hitwall
.nof:
    mov     eax, [lines + rsi + LN_FRONTSEC]
    imul    eax, SECTOR_SIZE
    mov     edx, [lines + rsi + LN_BACKSEC]
    imul    edx, SECTOR_SIZE
    mov     ecx, [sectors + rax + SEC_CEILH]
    cmp     ecx, [sectors + rdx + SEC_CEILH]
    je      .noc
    mov     ecx, [opentop]
    sub     ecx, [shootz]
    mov     edx, r12d
    call    FixedDiv
    cmp     eax, [aimslope]
    jl      .hitwall
.noc:
    mov     eax, 1
    jmp     .out

.hitwall:
    ; точка попадания
    mov     ecx, [attackrange]
    mov     edx, [rbx + IC_FRAC]
    call    FixedMul
    mov     r12d, eax
    mov     ecx, [trace + 8]
    mov     edx, [rbx + IC_FRAC]
    call    FixedMul
    add     eax, [trace + 0]
    mov     r13d, eax                   ; x
    mov     ecx, [trace + 12]
    mov     edx, [rbx + IC_FRAC]
    call    FixedMul
    add     eax, [trace + 4]
    mov     r14d, eax                   ; y
    mov     ecx, [aimslope]
    mov     edx, r12d
    call    FixedMul
    add     eax, [shootz]
    mov     edi, eax                    ; z
    ; небо не оставляет следов
    mov     esi, [rbx + IC_PTR]
    mov     eax, [lines + rsi + LN_FRONTSEC]
    imul    eax, SECTOR_SIZE
    mov     ecx, [sectors + rax + SEC_CEILPIC]
    cmp     ecx, [skyflatnum]
    jne     .puff
    mov     ecx, [sectors + rax + SEC_CEILH]
    cmp     edi, ecx
    jge     .stop
.puff:
    mov     ecx, r13d
    mov     edx, r14d
    mov     r8d, edi
    call    P_SpawnPuff
    jmp     .stop

.thing:
    mov     rsi, [rbx + IC_PTR]
    cmp     rsi, [shootthing]
    je      .cont
    test    dword [rsi + MO_FLAGS], MF_SHOOTABLE
    jz      .cont
    mov     ecx, [attackrange]
    mov     edx, [rbx + IC_FRAC]
    call    FixedMul
    mov     r12d, eax
    test    r12d, r12d
    jnz     .tdistok
    mov     r12d, 1
.tdistok:
    mov     ecx, [rsi + MO_Z]
    add     ecx, [rsi + MO_HEIGHT]
    sub     ecx, [shootz]
    mov     edx, r12d
    call    FixedDiv
    cmp     eax, [aimslope]
    jl      .cont
    mov     ecx, [rsi + MO_Z]
    sub     ecx, [shootz]
    mov     edx, r12d
    call    FixedDiv
    cmp     eax, [aimslope]
    jg      .cont
    ; точка попадания
    mov     ecx, [trace + 8]
    mov     edx, [rbx + IC_FRAC]
    call    FixedMul
    add     eax, [trace + 0]
    mov     r13d, eax
    mov     ecx, [trace + 12]
    mov     edx, [rbx + IC_FRAC]
    call    FixedMul
    add     eax, [trace + 4]
    mov     r14d, eax
    mov     ecx, [aimslope]
    mov     edx, r12d
    call    FixedMul
    add     eax, [shootz]
    mov     edi, eax
    test    dword [rsi + MO_FLAGS], MF_NOBLOOD
    jnz     .puff2
    mov     ecx, r13d
    mov     edx, r14d
    mov     r8d, edi
    mov     r9d, [la_damage]
    call    P_SpawnBlood
    jmp     .dodamage
.puff2:
    mov     ecx, r13d
    mov     edx, r14d
    mov     r8d, edi
    call    P_SpawnPuff
.dodamage:
    cmp     dword [la_damage], 0
    je      .stop
    mov     rcx, rsi
    mov     rdx, [shootthing]
    mov     r8, [shootthing]
    mov     r9d, [la_damage]
    call    P_DamageMobj
    jmp     .stop
.cont:
    mov     eax, 1
    jmp     .out
.stop:
    xor     eax, eax
.out:
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_UseLines(rcx = mobj игрока)
; ---------------------------------------------------------------------------
P_UseLines:
    push    rbx
    push    rsi
    push    rdi
    mov     rbx, rcx
    mov     [usething], rbx
    mov     esi, [rbx + MO_ANGLE]
    shr     esi, ANGLETOFINESHIFT
    and     esi, FINEMASK
    mov     eax, [rbx + MO_X]
    mov     [pt_x1], eax
    mov     eax, [rbx + MO_Y]
    mov     [pt_y1], eax
    mov     eax, USERANGE >> FRACBITS
    imul    eax, [finecosine + rsi*4]
    add     eax, [rbx + MO_X]
    mov     [pt_x2], eax
    mov     eax, USERANGE >> FRACBITS
    imul    eax, [finesine + rsi*4]
    add     eax, [rbx + MO_Y]
    mov     [pt_y2], eax
    mov     ecx, PT_ADDLINES
    mov     rdx, PTR_UseTraverse
    call    P_PathTraverse
    pop     rdi
    pop     rsi
    pop     rbx
    ret

PTR_UseTraverse:
    push    rbx
    push    rsi
    mov     rbx, rcx
    mov     esi, [rbx + IC_PTR]
    cmp     dword [lines + rsi + LN_SPECIAL], 0
    jne     .special
    mov     r8d, esi
    call    P_LineOpening
    cmp     dword [openrange], 0
    jg      .cont
    mov     rcx, [usething]
    mov     edx, sfx_noway
    call    S_StartSound
    xor     eax, eax
    jmp     .out
.cont:
    mov     eax, 1
    jmp     .out
.special:
    mov     rdx, [usething]
    mov     ecx, [rdx + MO_X]
    mov     r8d, esi
    mov     edx, [rdx + MO_Y]
    call    P_PointOnLineSide
    mov     ecx, esi
    mov     edx, eax
    mov     r8, [usething]
    call    P_UseSpecialLine
    xor     eax, eax
.out:
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_CheckSight(rcx = t1, rdx = t2) -> eax
; ---------------------------------------------------------------------------
P_CheckSight:
    push    rbx
    push    rsi
    mov     rbx, rcx
    mov     rsi, rdx
    mov     eax, [rbx + MO_Z]
    mov     ecx, [rbx + MO_HEIGHT]
    mov     edx, ecx
    sar     edx, 2
    sub     ecx, edx
    add     eax, ecx
    mov     [sightzstart], eax
    mov     ecx, [rsi + MO_Z]
    add     ecx, [rsi + MO_HEIGHT]
    sub     ecx, eax
    mov     [topslope], ecx
    mov     ecx, [rsi + MO_Z]
    sub     ecx, eax
    mov     [bottomslope], ecx
    mov     eax, [rbx + MO_X]
    mov     [pt_x1], eax
    mov     eax, [rbx + MO_Y]
    mov     [pt_y1], eax
    mov     eax, [rsi + MO_X]
    mov     [pt_x2], eax
    mov     eax, [rsi + MO_Y]
    mov     [pt_y2], eax
    mov     ecx, PT_ADDLINES
    mov     rdx, PTR_SightTraverse
    call    P_PathTraverse
    pop     rsi
    pop     rbx
    ret

PTR_SightTraverse:
    push    rbx
    push    rsi
    mov     rbx, rcx
    mov     esi, [rbx + IC_PTR]
    test    dword [lines + rsi + LN_FLAGS], ML_TWOSIDED
    jz      .stop
    mov     r8d, esi
    call    P_LineOpening
    cmp     dword [openrange], 0
    jle     .stop
    mov     eax, [lines + rsi + LN_FRONTSEC]
    imul    eax, SECTOR_SIZE
    mov     edx, [lines + rsi + LN_BACKSEC]
    imul    edx, SECTOR_SIZE
    mov     ecx, [sectors + rax + SEC_FLOORH]
    cmp     ecx, [sectors + rdx + SEC_FLOORH]
    je      .nof
    mov     ecx, [openbottom]
    sub     ecx, [sightzstart]
    mov     edx, [rbx + IC_FRAC]
    call    FixedDiv
    cmp     eax, [bottomslope]
    jle     .nof
    mov     [bottomslope], eax
.nof:
    mov     eax, [lines + rsi + LN_FRONTSEC]
    imul    eax, SECTOR_SIZE
    mov     edx, [lines + rsi + LN_BACKSEC]
    imul    edx, SECTOR_SIZE
    mov     ecx, [sectors + rax + SEC_CEILH]
    cmp     ecx, [sectors + rdx + SEC_CEILH]
    je      .noc
    mov     ecx, [opentop]
    sub     ecx, [sightzstart]
    mov     edx, [rbx + IC_FRAC]
    call    FixedDiv
    cmp     eax, [topslope]
    jge     .noc
    mov     [topslope], eax
.noc:
    mov     eax, [topslope]
    cmp     eax, [bottomslope]
    jle     .stop
    mov     eax, 1
    pop     rsi
    pop     rbx
    ret
.stop:
    xor     eax, eax
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_RadiusAttack(rcx = источник, rdx = виновник, r8d = урон)
; ---------------------------------------------------------------------------
P_RadiusAttack:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     [bombspot], rcx
    mov     [bombsource], rdx
    mov     [bombdamage], r8d
    mov     eax, r8d
    add     eax, 32
    shl     eax, FRACBITS
    mov     [bombdist], eax
    mov     rbx, rcx
    mov     eax, [rbx + MO_X]
    sub     eax, [bombdist]
    sub     eax, [bmaporgx]
    sar     eax, MAPBLOCKSHIFT
    mov     r12d, eax
    mov     eax, [rbx + MO_X]
    add     eax, [bombdist]
    sub     eax, [bmaporgx]
    sar     eax, MAPBLOCKSHIFT
    mov     r13d, eax
    mov     eax, [rbx + MO_Y]
    sub     eax, [bombdist]
    sub     eax, [bmaporgy]
    sar     eax, MAPBLOCKSHIFT
    mov     r14d, eax
    mov     eax, [rbx + MO_Y]
    add     eax, [bombdist]
    sub     eax, [bmaporgy]
    sar     eax, MAPBLOCKSHIFT
    mov     r15d, eax
    mov     esi, r12d
.bx:
    cmp     esi, r13d
    jg      .done
    mov     edi, r14d
.by:
    cmp     edi, r15d
    jg      .bxn
    mov     ecx, esi
    mov     edx, edi
    mov     r8, PIT_RadiusAttack
    call    P_BlockThingsIterator
    inc     edi
    jmp     .by
.bxn:
    inc     esi
    jmp     .bx
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

PIT_RadiusAttack:
    push    rbx
    push    rsi
    push    rdi
    mov     rbx, rcx
    test    dword [rbx + MO_FLAGS], MF_SHOOTABLE
    jz      .ok
    mov     rsi, [bombspot]
    ; расстояние
    mov     eax, [rbx + MO_X]
    sub     eax, [rsi + MO_X]
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    mov     edi, eax
    mov     eax, [rbx + MO_Y]
    sub     eax, [rsi + MO_Y]
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    cmp     eax, edi
    jle     .maxok
    mov     edi, eax
.maxok:
    sub     edi, [rbx + MO_RADIUS]
    sar     edi, FRACBITS
    test    edi, edi
    jns     .distpos
    xor     edi, edi
.distpos:
    cmp     edi, [bombdamage]
    jge     .ok
    mov     rcx, rbx
    mov     rdx, rsi
    call    P_CheckSight
    test    eax, eax
    jz      .ok
    mov     eax, [bombdamage]
    sub     eax, edi
    mov     rcx, rbx
    mov     rdx, [bombspot]
    mov     r8, [bombsource]
    mov     r9d, eax
    call    P_DamageMobj
.ok:
    mov     eax, 1
    pop     rdi
    pop     rsi
    pop     rbx
    ret
