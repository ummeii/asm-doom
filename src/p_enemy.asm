; ===========================================================================
;  p_enemy.asm -- искусственный интеллект монстров (порт p_enemy.c)
; ===========================================================================

%define DI_NODIR    8
%define SKULLSPEED  (20*FRACUNIT)

; ---------------------------------------------------------------------------
;  P_CheckMeleeRange(rcx = актор) -> eax
; ---------------------------------------------------------------------------
P_CheckMeleeRange:
    push    rbx
    push    rsi
    mov     rbx, rcx
    mov     rsi, [rbx + MO_TARGET]
    test    rsi, rsi
    jz      .no
    mov     ecx, [rsi + MO_X]
    sub     ecx, [rbx + MO_X]
    mov     edx, [rsi + MO_Y]
    sub     edx, [rbx + MO_Y]
    call    P_AproxDistance
    mov     ecx, MELEERANGE - 20*FRACUNIT
    add     ecx, [rsi + MO_RADIUS]
    cmp     eax, ecx
    jge     .no
    mov     rcx, rbx
    mov     rdx, rsi
    call    P_CheckSight
    test    eax, eax
    jz      .no
    mov     eax, 1
    pop     rsi
    pop     rbx
    ret
.no:
    xor     eax, eax
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_CheckMissileRange(rcx = актор) -> eax
; ---------------------------------------------------------------------------
P_CheckMissileRange:
    push    rbx
    push    rsi
    push    rdi
    mov     rbx, rcx
    mov     rsi, [rbx + MO_TARGET]
    test    rsi, rsi
    jz      .no
    mov     rcx, rbx
    mov     rdx, rsi
    call    P_CheckSight
    test    eax, eax
    jz      .no
    test    dword [rbx + MO_FLAGS], MF_JUSTHIT
    jz      .nojusthit
    and     dword [rbx + MO_FLAGS], ~MF_JUSTHIT
    mov     eax, 1
    jmp     .out
.nojusthit:
    cmp     dword [rbx + MO_REACTIONTIME], 0
    jne     .no
    mov     ecx, [rbx + MO_X]
    sub     ecx, [rsi + MO_X]
    mov     edx, [rbx + MO_Y]
    sub     edx, [rsi + MO_Y]
    call    P_AproxDistance
    sub     eax, 64*FRACUNIT
    mov     rdx, [rbx + MO_INFO]
    cmp     dword [rdx + MI_MELEESTATE], 0
    jne     .hasmelee
    sub     eax, 128*FRACUNIT
.hasmelee:
    sar     eax, 16
    mov     edi, eax
    cmp     dword [rbx + MO_TYPE], MT_SKULL
    jne     .noskull
    sar     edi, 1
.noskull:
    cmp     edi, 200
    jle     .distok
    mov     edi, 200
.distok:
    call    P_Random
    cmp     eax, edi
    jl      .no
    mov     eax, 1
    jmp     .out
.no:
    xor     eax, eax
.out:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_Move(rcx = актор) -> eax
; ---------------------------------------------------------------------------
P_Move:
    push    rbx
    push    rsi
    push    rdi
    mov     rbx, rcx
    mov     eax, [rbx + MO_MOVEDIR]
    cmp     eax, DI_NODIR
    jae     .no
    mov     rdx, [rbx + MO_INFO]
    mov     ecx, [rdx + MI_SPEED]
    mov     esi, [xspeed + rax*4]
    imul    esi, ecx
    add     esi, [rbx + MO_X]
    mov     eax, [rbx + MO_MOVEDIR]
    mov     edi, [yspeed + rax*4]
    imul    edi, ecx
    add     edi, [rbx + MO_Y]
    mov     rcx, rbx
    mov     edx, esi
    mov     r8d, edi
    call    P_TryMove
    test    eax, eax
    jnz     .moved
    ; парящие могут подняться/опуститься
    test    dword [rbx + MO_FLAGS], MF_FLOAT
    jz      .nofloat
    cmp     dword [floatok], 0
    je      .nofloat
    mov     eax, [rbx + MO_Z]
    cmp     eax, [tmfloorz]
    jge     .down
    add     dword [rbx + MO_Z], FLOATSPEED
    jmp     .floated
.down:
    sub     dword [rbx + MO_Z], FLOATSPEED
.floated:
    or      dword [rbx + MO_FLAGS], MF_INFLOAT
    mov     eax, 1
    jmp     .out
.nofloat:
    cmp     dword [numspechit], 0
    je      .no
    mov     dword [rbx + MO_MOVEDIR], DI_NODIR
    xor     esi, esi                    ; good
.spec:
    cmp     dword [numspechit], 0
    je      .specdone
    dec     dword [numspechit]
    mov     eax, [numspechit]
    mov     ecx, [spechit + rax*4]
    xor     edx, edx
    mov     r8, rbx
    call    P_UseSpecialLine
    test    eax, eax
    jz      .spec
    mov     esi, 1
    jmp     .spec
.specdone:
    mov     eax, esi
    jmp     .out
.moved:
    and     dword [rbx + MO_FLAGS], ~MF_INFLOAT
    test    dword [rbx + MO_FLAGS], MF_FLOAT
    jnz     .nofix
    mov     eax, [rbx + MO_FLOORZ]
    mov     [rbx + MO_Z], eax
.nofix:
    mov     eax, 1
    jmp     .out
.no:
    xor     eax, eax
.out:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_TryWalk(rcx = актор) -> eax
; ---------------------------------------------------------------------------
P_TryWalk:
    push    rbx
    mov     rbx, rcx
    call    P_Move
    test    eax, eax
    jz      .no
    call    P_Random
    and     eax, 15
    mov     [rbx + MO_MOVECOUNT], eax
    mov     eax, 1
    pop     rbx
    ret
.no:
    xor     eax, eax
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_NewChaseDir(rcx = актор)
; ---------------------------------------------------------------------------
P_NewChaseDir:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rcx
    mov     rsi, [rbx + MO_TARGET]
    test    rsi, rsi
    jz      .done
    mov     r12d, [rbx + MO_MOVEDIR]    ; olddir
    mov     r13d, r12d
    xor     r13d, 4
    cmp     r13d, 8
    jb      .turnok
    mov     r13d, DI_NODIR
.turnok:                                ; r13 = turnaround
    mov     eax, [rsi + MO_X]
    sub     eax, [rbx + MO_X]
    mov     r14d, eax                   ; deltax
    mov     eax, [rsi + MO_Y]
    sub     eax, [rbx + MO_Y]
    mov     r15d, eax                   ; deltay

    ; d[1] по X
    mov     dword [chd1], DI_NODIR
    cmp     r14d, 10*FRACUNIT
    jle     .dx1
    mov     dword [chd1], 0             ; DI_EAST
    jmp     .dxd
.dx1:
    cmp     r14d, -10*FRACUNIT
    jge     .dxd
    mov     dword [chd1], 4             ; DI_WEST
.dxd:
    ; d[2] по Y
    mov     dword [chd2], DI_NODIR
    cmp     r15d, -10*FRACUNIT
    jge     .dy1
    mov     dword [chd2], 6             ; DI_SOUTH
    jmp     .dyd
.dy1:
    cmp     r15d, 10*FRACUNIT
    jle     .dyd
    mov     dword [chd2], 2             ; DI_NORTH
.dyd:
    ; попробовать диагональ
    cmp     dword [chd1], DI_NODIR
    je      .nodiag
    cmp     dword [chd2], DI_NODIR
    je      .nodiag
    xor     eax, eax
    cmp     r15d, 0
    jge     .di1
    mov     eax, 1
.di1:
    xor     ecx, ecx
    cmp     r14d, 0
    jge     .di2
    mov     ecx, 1
.di2:
    shl     eax, 1
    add     eax, ecx
    mov     eax, [diags + rax*4]
    mov     [rbx + MO_MOVEDIR], eax
    cmp     eax, r13d
    je      .nodiag
    mov     rcx, rbx
    call    P_TryWalk
    test    eax, eax
    jnz     .done
.nodiag:
    ; попробовать дальнюю ось первой
    call    P_Random
    cmp     eax, 200
    jl      .noswap
    mov     eax, [chd1]
    mov     ecx, [chd2]
    mov     [chd1], ecx
    mov     [chd2], eax
    jmp     .tryd1
.noswap:
    mov     eax, r14d
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    mov     edx, r15d
    mov     ecx, edx
    sar     ecx, 31
    xor     edx, ecx
    sub     edx, ecx
    cmp     eax, edx
    jge     .tryd1
    mov     eax, [chd1]
    mov     ecx, [chd2]
    mov     [chd1], ecx
    mov     [chd2], eax
.tryd1:
    mov     eax, [chd1]
    cmp     eax, r13d
    jne     .d1ok
    mov     dword [chd1], DI_NODIR
.d1ok:
    mov     eax, [chd2]
    cmp     eax, r13d
    jne     .d2ok
    mov     dword [chd2], DI_NODIR
.d2ok:
    cmp     dword [chd1], DI_NODIR
    je      .try2
    mov     eax, [chd1]
    mov     [rbx + MO_MOVEDIR], eax
    mov     rcx, rbx
    call    P_TryWalk
    test    eax, eax
    jnz     .done
.try2:
    cmp     dword [chd2], DI_NODIR
    je      .tryold
    mov     eax, [chd2]
    mov     [rbx + MO_MOVEDIR], eax
    mov     rcx, rbx
    call    P_TryWalk
    test    eax, eax
    jnz     .done
.tryold:
    cmp     r12d, DI_NODIR
    je      .tryall
    mov     [rbx + MO_MOVEDIR], r12d
    mov     rcx, rbx
    call    P_TryWalk
    test    eax, eax
    jnz     .done
.tryall:
    ; перебор всех направлений
    call    P_Random
    test    eax, 1
    jnz     .backward
    xor     edi, edi
.fwd:
    cmp     edi, 8
    jae     .lastresort
    cmp     edi, r13d
    je      .fwdnext
    mov     [rbx + MO_MOVEDIR], edi
    mov     rcx, rbx
    call    P_TryWalk
    test    eax, eax
    jnz     .done
.fwdnext:
    inc     edi
    jmp     .fwd
.backward:
    mov     edi, 7
.bwd:
    test    edi, edi
    js      .lastresort
    cmp     edi, r13d
    je      .bwdnext
    mov     [rbx + MO_MOVEDIR], edi
    mov     rcx, rbx
    call    P_TryWalk
    test    eax, eax
    jnz     .done
.bwdnext:
    dec     edi
    jmp     .bwd
.lastresort:
    cmp     r13d, DI_NODIR
    je      .nodir
    mov     [rbx + MO_MOVEDIR], r13d
    mov     rcx, rbx
    call    P_TryWalk
    test    eax, eax
    jnz     .done
.nodir:
    mov     dword [rbx + MO_MOVEDIR], DI_NODIR
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
;  P_LookForPlayers(rcx = актор, edx = смотреть вокруг) -> eax
; ---------------------------------------------------------------------------
P_LookForPlayers:
    push    rbx
    push    rsi
    push    rdi
    mov     rbx, rcx
    mov     edi, edx
    cmp     dword [player + PL_HEALTH], 0
    jle     .no
    mov     rsi, [playermo]
    test    rsi, rsi
    jz      .no
    mov     rcx, rbx
    mov     rdx, rsi
    call    P_CheckSight
    test    eax, eax
    jz      .no
    test    edi, edi
    jnz     .accept
    ; сектор обзора 180 градусов
    mov     ecx, [rbx + MO_X]
    mov     edx, [rbx + MO_Y]
    mov     r8d, [rsi + MO_X]
    mov     r9d, [rsi + MO_Y]
    call    R_PointToAngle2
    sub     eax, [rbx + MO_ANGLE]
    cmp     eax, ANG90
    jbe     .accept
    cmp     eax, ANG270
    jae     .accept
    ; сзади -- только вплотную
    mov     ecx, [rsi + MO_X]
    sub     ecx, [rbx + MO_X]
    mov     edx, [rsi + MO_Y]
    sub     edx, [rbx + MO_Y]
    call    P_AproxDistance
    cmp     eax, MELEERANGE
    jg      .no
.accept:
    mov     [rbx + MO_TARGET], rsi
    mov     eax, 1
    pop     rdi
    pop     rsi
    pop     rbx
    ret
.no:
    xor     eax, eax
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ===========================================================================
;  Действия состояний
; ===========================================================================

A_NULL_f:
    ret

; ---- A_Look ----
A_Look_f:
    push    rbx
    push    rsi
    mov     rbx, rcx
    mov     dword [rbx + MO_THRESHOLD], 0
    mov     eax, [rbx + MO_SECTOR]
    cmp     eax, -1
    je      .nosound
    imul    eax, SECTOR_SIZE
    mov     rsi, [sectors + rax + SEC_SOUNDTARGET]
    test    rsi, rsi
    jz      .nosound
    test    dword [rsi + MO_FLAGS], MF_SHOOTABLE
    jz      .nosound
    mov     [rbx + MO_TARGET], rsi
    test    dword [rbx + MO_FLAGS], MF_AMBUSH
    jz      .seeyou
    mov     rcx, rbx
    mov     rdx, rsi
    call    P_CheckSight
    test    eax, eax
    jnz     .seeyou
.nosound:
    mov     rcx, rbx
    xor     edx, edx
    call    P_LookForPlayers
    test    eax, eax
    jz      .done
.seeyou:
    mov     rdx, [rbx + MO_INFO]
    mov     edx, [rdx + MI_SEESOUND]
    test    edx, edx
    jz      .nosnd
    mov     rcx, rbx
    call    S_StartSound
.nosnd:
    mov     rdx, [rbx + MO_INFO]
    mov     edx, [rdx + MI_SEESTATE]
    mov     rcx, rbx
    call    P_SetMobjState
.done:
    pop     rsi
    pop     rbx
    ret

; ---- A_Chase ----
A_Chase_f:
    push    rbx
    push    rsi
    push    rdi
    mov     rbx, rcx
    cmp     dword [rbx + MO_REACTIONTIME], 0
    je      .nort
    dec     dword [rbx + MO_REACTIONTIME]
.nort:
    cmp     dword [rbx + MO_THRESHOLD], 0
    je      .noth
    mov     rsi, [rbx + MO_TARGET]
    test    rsi, rsi
    jz      .clrth
    cmp     dword [rsi + MO_HEALTH], 0
    jg      .decth
.clrth:
    mov     dword [rbx + MO_THRESHOLD], 0
    jmp     .noth
.decth:
    dec     dword [rbx + MO_THRESHOLD]
.noth:
    ; довернуть в сторону движения
    mov     eax, [rbx + MO_MOVEDIR]
    cmp     eax, 8
    jae     .noturn
    and     dword [rbx + MO_ANGLE], 7<<29
    mov     ecx, eax
    shl     ecx, 29
    mov     eax, [rbx + MO_ANGLE]
    sub     eax, ecx
    test    eax, eax
    jz      .noturn
    js      .turnup
    sub     dword [rbx + MO_ANGLE], ANG90/2
    jmp     .noturn
.turnup:
    add     dword [rbx + MO_ANGLE], ANG90/2
.noturn:
    ; есть ли цель
    mov     rsi, [rbx + MO_TARGET]
    test    rsi, rsi
    jz      .newtarget
    test    dword [rsi + MO_FLAGS], MF_SHOOTABLE
    jnz     .havetarget
.newtarget:
    mov     rcx, rbx
    mov     edx, 1
    call    P_LookForPlayers
    test    eax, eax
    jnz     .done
    mov     rdx, [rbx + MO_INFO]
    mov     edx, [rdx + MI_SPAWNSTATE]
    mov     rcx, rbx
    call    P_SetMobjState
    jmp     .done
.havetarget:
    ; не атаковать дважды подряд
    test    dword [rbx + MO_FLAGS], MF_JUSTATTACKED
    jz      .noja
    and     dword [rbx + MO_FLAGS], ~MF_JUSTATTACKED
    mov     rcx, rbx
    call    P_NewChaseDir
    jmp     .done
.noja:
    ; ближний бой
    mov     rdx, [rbx + MO_INFO]
    cmp     dword [rdx + MI_MELEESTATE], 0
    je      .nomelee
    mov     rcx, rbx
    call    P_CheckMeleeRange
    test    eax, eax
    jz      .nomelee
    mov     rdx, [rbx + MO_INFO]
    mov     edx, [rdx + MI_ATTACKSOUND]
    test    edx, edx
    jz      .nomsnd
    mov     rcx, rbx
    call    S_StartSound
.nomsnd:
    mov     rdx, [rbx + MO_INFO]
    mov     edx, [rdx + MI_MELEESTATE]
    mov     rcx, rbx
    call    P_SetMobjState
    jmp     .done
.nomelee:
    ; дальняя атака
    mov     rdx, [rbx + MO_INFO]
    cmp     dword [rdx + MI_MISSILESTATE], 0
    je      .nomissile
    cmp     dword [rbx + MO_MOVECOUNT], 0
    jne     .nomissile
    mov     rcx, rbx
    call    P_CheckMissileRange
    test    eax, eax
    jz      .nomissile
    mov     rdx, [rbx + MO_INFO]
    mov     edx, [rdx + MI_MISSILESTATE]
    mov     rcx, rbx
    call    P_SetMobjState
    or      dword [rbx + MO_FLAGS], MF_JUSTATTACKED
    jmp     .done
.nomissile:
    dec     dword [rbx + MO_MOVECOUNT]
    js      .newdir
    mov     rcx, rbx
    call    P_Move
    test    eax, eax
    jnz     .moveok
.newdir:
    mov     rcx, rbx
    call    P_NewChaseDir
.moveok:
    mov     rdx, [rbx + MO_INFO]
    mov     edx, [rdx + MI_ACTIVESOUND]
    test    edx, edx
    jz      .done
    push    rdx
    call    P_Random
    pop     rdx
    cmp     eax, 3
    jge     .done
    mov     rcx, rbx
    call    S_StartSound
.done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---- A_FaceTarget ----
A_FaceTarget_f:
    push    rbx
    push    rsi
    mov     rbx, rcx
    mov     rsi, [rbx + MO_TARGET]
    test    rsi, rsi
    jz      .done
    and     dword [rbx + MO_FLAGS], ~MF_AMBUSH
    mov     ecx, [rbx + MO_X]
    mov     edx, [rbx + MO_Y]
    mov     r8d, [rsi + MO_X]
    mov     r9d, [rsi + MO_Y]
    call    R_PointToAngle2
    mov     [rbx + MO_ANGLE], eax
    test    dword [rsi + MO_FLAGS], MF_SHADOW
    jz      .done
    call    P_SubRandom
    shl     eax, 21
    add     [rbx + MO_ANGLE], eax
.done:
    pop     rsi
    pop     rbx
    ret

; ---- A_PosAttack (пистолет зомби) ----
A_PosAttack_f:
    push    rbx
    push    rsi
    push    rdi
    mov     rbx, rcx
    cmp     qword [rbx + MO_TARGET], 0
    je      .done
    mov     rcx, rbx
    call    A_FaceTarget_f
    mov     esi, [rbx + MO_ANGLE]
    mov     rcx, rbx
    mov     edx, esi
    mov     r8d, MISSILERANGE
    call    P_AimLineAttack
    mov     edi, eax
    mov     rcx, rbx
    mov     edx, sfx_pistol
    call    S_StartSound
    call    P_SubRandom
    shl     eax, 20
    add     esi, eax
    call    P_Random
    xor     edx, edx
    mov     ecx, 5
    div     ecx
    inc     edx
    imul    edx, 3
    mov     [la_damage], edx
    mov     rcx, rbx
    mov     edx, esi
    mov     r8d, MISSILERANGE
    mov     r9d, edi
    call    P_LineAttack
.done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---- A_SPosAttack (дробовик сержанта: 3 дробины) ----
A_SPosAttack_f:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    mov     rbx, rcx
    cmp     qword [rbx + MO_TARGET], 0
    je      .done
    mov     rcx, rbx
    mov     edx, sfx_shotgn
    call    S_StartSound
    mov     rcx, rbx
    call    A_FaceTarget_f
    mov     esi, [rbx + MO_ANGLE]
    mov     rcx, rbx
    mov     edx, esi
    mov     r8d, MISSILERANGE
    call    P_AimLineAttack
    mov     edi, eax
    mov     r12d, 3
.shot:
    call    P_SubRandom
    shl     eax, 20
    add     eax, esi
    push    rax
    call    P_Random
    xor     edx, edx
    mov     ecx, 5
    div     ecx
    inc     edx
    imul    edx, 3
    mov     [la_damage], edx
    pop     rax
    mov     rcx, rbx
    mov     edx, eax
    mov     r8d, MISSILERANGE
    mov     r9d, edi
    call    P_LineAttack
    dec     r12d
    jnz     .shot
.done:
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---- A_TroopAttack (имп) ----
A_TroopAttack_f:
    push    rbx
    mov     rbx, rcx
    cmp     qword [rbx + MO_TARGET], 0
    je      .done
    mov     rcx, rbx
    call    A_FaceTarget_f
    mov     rcx, rbx
    call    P_CheckMeleeRange
    test    eax, eax
    jz      .missile
    mov     rcx, rbx
    mov     edx, sfx_claw
    call    S_StartSound
    call    P_Random
    and     eax, 7
    inc     eax
    imul    eax, 3
    mov     rcx, [rbx + MO_TARGET]
    mov     rdx, rbx
    mov     r8, rbx
    mov     r9d, eax
    call    P_DamageMobj
    jmp     .done
.missile:
    mov     rcx, rbx
    mov     rdx, [rbx + MO_TARGET]
    mov     r8d, MT_TROOPSHOT
    call    P_SpawnMissile
.done:
    pop     rbx
    ret

; ---- A_SargAttack (демон) ----
A_SargAttack_f:
    push    rbx
    mov     rbx, rcx
    cmp     qword [rbx + MO_TARGET], 0
    je      .done
    mov     rcx, rbx
    call    A_FaceTarget_f
    mov     rcx, rbx
    call    P_CheckMeleeRange
    test    eax, eax
    jz      .done
    call    P_Random
    xor     edx, edx
    mov     ecx, 10
    div     ecx
    inc     edx
    imul    edx, 4
    mov     rcx, [rbx + MO_TARGET]
    mov     r9d, edx
    mov     rdx, rbx
    mov     r8, rbx
    call    P_DamageMobj
.done:
    pop     rbx
    ret

; ---- A_HeadAttack (какодемон) ----
A_HeadAttack_f:
    push    rbx
    mov     rbx, rcx
    cmp     qword [rbx + MO_TARGET], 0
    je      .done
    mov     rcx, rbx
    call    A_FaceTarget_f
    mov     rcx, rbx
    call    P_CheckMeleeRange
    test    eax, eax
    jz      .missile
    call    P_Random
    xor     edx, edx
    mov     ecx, 6
    div     ecx
    inc     edx
    imul    edx, 10
    mov     rcx, [rbx + MO_TARGET]
    mov     r9d, edx
    mov     rdx, rbx
    mov     r8, rbx
    call    P_DamageMobj
    jmp     .done
.missile:
    mov     rcx, rbx
    mov     rdx, [rbx + MO_TARGET]
    mov     r8d, MT_BRUISERSHOT
    call    P_SpawnMissile
.done:
    pop     rbx
    ret

; ---- A_BruisAttack (барон) ----
A_BruisAttack_f:
    push    rbx
    mov     rbx, rcx
    cmp     qword [rbx + MO_TARGET], 0
    je      .done
    mov     rcx, rbx
    call    P_CheckMeleeRange
    test    eax, eax
    jz      .missile
    mov     rcx, rbx
    mov     edx, sfx_claw
    call    S_StartSound
    call    P_Random
    and     eax, 7
    inc     eax
    imul    eax, 10
    mov     rcx, [rbx + MO_TARGET]
    mov     rdx, rbx
    mov     r8, rbx
    mov     r9d, eax
    call    P_DamageMobj
    jmp     .done
.missile:
    mov     rcx, rbx
    mov     rdx, [rbx + MO_TARGET]
    mov     r8d, MT_BRUISERSHOT
    call    P_SpawnMissile
.done:
    pop     rbx
    ret

; ---- A_SkullAttack (потерянная душа) ----
A_SkullAttack_f:
    push    rbx
    push    rsi
    push    rdi
    mov     rbx, rcx
    mov     rsi, [rbx + MO_TARGET]
    test    rsi, rsi
    jz      .done
    mov     rcx, rbx
    mov     rdx, [rbx + MO_INFO]
    mov     edx, [rdx + MI_ATTACKSOUND]
    call    S_StartSound
    mov     rcx, rbx
    call    A_FaceTarget_f
    or      dword [rbx + MO_FLAGS], MF_SKULLFLY
    mov     eax, [rbx + MO_ANGLE]
    shr     eax, ANGLETOFINESHIFT
    and     eax, FINEMASK
    mov     ecx, SKULLSPEED
    mov     edx, [finecosine + rax*4]
    push    rax
    call    FixedMul
    mov     [rbx + MO_MOMX], eax
    pop     rax
    mov     ecx, SKULLSPEED
    mov     edx, [finesine + rax*4]
    call    FixedMul
    mov     [rbx + MO_MOMY], eax
    ; вертикаль
    mov     ecx, [rsi + MO_X]
    sub     ecx, [rbx + MO_X]
    mov     edx, [rsi + MO_Y]
    sub     edx, [rbx + MO_Y]
    call    P_AproxDistance
    mov     ecx, eax
    mov     edx, SKULLSPEED
    call    FixedDiv
    mov     edi, eax
    test    edi, edi
    jg      .distok
    mov     edi, 1
.distok:
    mov     eax, [rsi + MO_Z]
    mov     ecx, [rsi + MO_HEIGHT]
    sar     ecx, 1
    add     eax, ecx
    sub     eax, [rbx + MO_Z]
    cdq
    idiv    edi
    mov     [rbx + MO_MOMZ], eax
.done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---- звуки смерти и боли ----
A_Scream_f:
    push    rbx
    mov     rbx, rcx
    mov     rdx, [rbx + MO_INFO]
    mov     edx, [rdx + MI_DEATHSOUND]
    test    edx, edx
    jz      .done
    mov     rcx, rbx
    call    S_StartSound
.done:
    pop     rbx
    ret

A_XScream_f:
    mov     edx, sfx_slop
    jmp     S_StartSound

A_Pain_f:
    push    rbx
    mov     rbx, rcx
    mov     rdx, [rbx + MO_INFO]
    mov     edx, [rdx + MI_PAINSOUND]
    test    edx, edx
    jz      .done
    mov     rcx, rbx
    call    S_StartSound
.done:
    pop     rbx
    ret

A_Fall_f:
    and     dword [rcx + MO_FLAGS], ~MF_SOLID
    ret

A_Explode_f:
    mov     rdx, [rcx + MO_TARGET]
    mov     r8d, 128
    jmp     P_RadiusAttack

A_BossDeath_f:
    mov     byte [g_exitlevel], 1
    ret

A_PlayerScream_f:
    mov     edx, sfx_pldeth
    jmp     S_StartSound
