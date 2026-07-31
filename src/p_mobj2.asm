; ===========================================================================
;  p_mobj2.asm -- машина состояний, движение объектов, снаряды и эффекты
; ===========================================================================

%define STOPSPEED   0x1000
%define FRICTION    0xe800
%define MAXMOVE     (30*FRACUNIT)
%define GRAVITY     FRACUNIT
%define FLOATSPEED  (FRACUNIT*4)

; ---------------------------------------------------------------------------
;  P_SetMobjState(rcx = mobj, edx = номер состояния) -> eax (0 = объект убран)
; ---------------------------------------------------------------------------
P_SetMobjState:
    push    rbx
    push    rsi
    push    rdi
    mov     rbx, rcx
    mov     esi, edx
.loop:
    test    esi, esi
    jnz     .havestate
    mov     qword [rbx + MO_STATE], 0
    mov     rcx, rbx
    call    P_RemoveMobj
    xor     eax, eax
    jmp     .out
.havestate:
    imul    eax, esi, STATE_SIZE
    lea     rdi, [states]
    add     rdi, rax
    mov     [rbx + MO_STATE], rdi
    mov     eax, [rdi + ST_TICS]
    mov     [rbx + MO_TICS], eax
    mov     eax, [rdi + ST_SPRITE]
    mov     [rbx + MO_SPRITE], eax
    mov     eax, [rdi + ST_FRAME]
    mov     [rbx + MO_FRAME], eax
    mov     eax, [rdi + ST_ACTION]
    test    eax, eax
    jz      .noaction
    lea     rdx, [action_table]
    mov     rdx, [rdx + rax*8]
    mov     rcx, rbx
    call    rdx
    cmp     dword [rbx + MO_INUSE], 0
    je      .removed
.noaction:
    mov     esi, [rdi + ST_NEXT]
    cmp     dword [rbx + MO_TICS], 0
    je      .loop
    mov     eax, 1
    jmp     .out
.removed:
    xor     eax, eax
.out:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_RunThinkers -- тик всех объектов
; ---------------------------------------------------------------------------
P_RunThinkers:
    push    rbx
    push    rsi
    xor     esi, esi
.l:
    mov     eax, esi
    imul    eax, MOBJ_SIZE
    lea     rbx, [mobjs]
    add     rbx, rax
    cmp     dword [rbx + MO_INUSE], 0
    je      .next
    ; объект игрока -- такой же thinker, как в DOOM: импульс от P_PlayerThink
    ; превращается в перемещение здесь, в P_XYMovement/P_ZMovement
    mov     rcx, rbx
    call    P_MobjThinker
.next:
    inc     esi
    cmp     esi, MAXMOBJS
    jb      .l
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_MobjThinker(rcx = mobj)
; ---------------------------------------------------------------------------
P_MobjThinker:
    push    rbx
    mov     rbx, rcx
    mov     eax, [rbx + MO_MOMX]
    or      eax, [rbx + MO_MOMY]
    jnz     .doxy
    test    dword [rbx + MO_FLAGS], MF_SKULLFLY
    jz      .noxy
.doxy:
    mov     rcx, rbx
    call    P_XYMovement
    cmp     dword [rbx + MO_INUSE], 0
    je      .done
.noxy:
    mov     eax, [rbx + MO_Z]
    cmp     eax, [rbx + MO_FLOORZ]
    jne     .doz
    cmp     dword [rbx + MO_MOMZ], 0
    je      .noz
.doz:
    mov     rcx, rbx
    call    P_ZMovement
    cmp     dword [rbx + MO_INUSE], 0
    je      .done
.noz:
    cmp     dword [rbx + MO_TICS], -1
    je      .respawn
    dec     dword [rbx + MO_TICS]
    cmp     dword [rbx + MO_TICS], 0
    jne     .done
    mov     rdx, [rbx + MO_STATE]
    mov     edx, [rdx + ST_NEXT]
    mov     rcx, rbx
    call    P_SetMobjState
    jmp     .done

    ; --- покойник в конечном кадре: «кошмар» поднимает его обратно ---
.respawn:
    test    dword [rbx + MO_FLAGS], MF_COUNTKILL
    jz      .done
    cmp     dword [respawnmonsters], 0
    je      .done
    inc     dword [rbx + MO_MOVECOUNT]
    cmp     dword [rbx + MO_MOVECOUNT], 12*35
    jl      .done
    test    dword [leveltime], 31
    jnz     .done
    call    P_Random
    cmp     eax, 4
    jg      .done
    mov     rcx, rbx
    call    P_NightmareRespawn
.done:
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_NightmareRespawn(rcx = труп) -- поднять монстра в точке появления
; ---------------------------------------------------------------------------
P_NightmareRespawn:
    push    rbx
    push    rsi
    push    rdi
    mov     rbx, rcx
    mov     esi, [rbx + MO_SPAWNX]
    shl     esi, 16
    mov     edi, [rbx + MO_SPAWNY]
    shl     edi, 16
    ; туман на месте смерти
    mov     ecx, [rbx + MO_X]
    mov     edx, [rbx + MO_Y]
    mov     r8d, [rbx + MO_FLOORZ]
    mov     r9d, MT_TFOG
    call    P_SpawnMobj
    ; туман в точке появления
    mov     ecx, esi
    mov     edx, edi
    mov     r8d, ONFLOORZ
    mov     r9d, MT_TFOG
    call    P_SpawnMobj
    ; сам монстр
    mov     ecx, esi
    mov     edx, edi
    mov     r8d, ONFLOORZ
    mov     r9d, [rbx + MO_TYPE]
    call    P_SpawnMobj
    test    rax, rax
    jz      .gone
    mov     ecx, [rbx + MO_SPAWNX]
    mov     [rax + MO_SPAWNX], ecx
    mov     ecx, [rbx + MO_SPAWNY]
    mov     [rax + MO_SPAWNY], ecx
    mov     ecx, [rbx + MO_SPAWNANG]
    mov     [rax + MO_SPAWNANG], ecx
    mov     ecx, [rbx + MO_SPAWNTYPE]
    mov     [rax + MO_SPAWNTYPE], ecx
    imul    ecx, [rbx + MO_SPAWNANG], ANG1
    mov     [rax + MO_ANGLE], ecx
    mov     dword [rax + MO_REACTIONTIME], 18
.gone:
    mov     rcx, rbx
    call    P_RemoveMobj
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_XYMovement(rcx = mobj)
; ---------------------------------------------------------------------------
P_XYMovement:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    mov     rbx, rcx
    mov     eax, [rbx + MO_MOMX]
    or      eax, [rbx + MO_MOMY]
    jnz     .moving
    test    dword [rbx + MO_FLAGS], MF_SKULLFLY
    jz      .done
    and     dword [rbx + MO_FLAGS], ~MF_SKULLFLY
    mov     dword [rbx + MO_MOMX], 0
    mov     dword [rbx + MO_MOMY], 0
    mov     dword [rbx + MO_MOMZ], 0
    mov     rdx, [rbx + MO_INFO]
    mov     edx, [rdx + MI_SPAWNSTATE]
    mov     rcx, rbx
    call    P_SetMobjState
    jmp     .done
.moving:
    ; ограничение скорости
    mov     eax, [rbx + MO_MOMX]
    cmp     eax, MAXMOVE
    jle     .mx1
    mov     dword [rbx + MO_MOMX], MAXMOVE
    jmp     .mx2
.mx1:
    cmp     eax, -MAXMOVE
    jge     .mx2
    mov     dword [rbx + MO_MOMX], -MAXMOVE
.mx2:
    mov     eax, [rbx + MO_MOMY]
    cmp     eax, MAXMOVE
    jle     .my1
    mov     dword [rbx + MO_MOMY], MAXMOVE
    jmp     .my2
.my1:
    cmp     eax, -MAXMOVE
    jge     .my2
    mov     dword [rbx + MO_MOMY], -MAXMOVE
.my2:
    mov     r12d, [rbx + MO_MOMX]       ; xmove
    mov     r13d, [rbx + MO_MOMY]       ; ymove
.steploop:
    mov     eax, r12d
    cmp     eax, MAXMOVE/2
    jg      .half
    cmp     r13d, MAXMOVE/2
    jg      .half
    mov     esi, [rbx + MO_X]
    add     esi, r12d
    mov     edi, [rbx + MO_Y]
    add     edi, r13d
    xor     r12d, r12d
    xor     r13d, r13d
    jmp     .try
.half:
    mov     esi, [rbx + MO_X]
    mov     eax, r12d
    sar     eax, 1
    add     esi, eax
    mov     edi, [rbx + MO_Y]
    mov     eax, r13d
    sar     eax, 1
    add     edi, eax
    sar     r12d, 1
    sar     r13d, 1
.try:
    mov     rcx, rbx
    mov     edx, esi
    mov     r8d, edi
    call    P_TryMove
    test    eax, eax
    jnz     .moveok
    ; не прошло
    cmp     qword [rbx + MO_PLAYER], 0
    je      .notplayer
    mov     rcx, rbx
    call    P_SlideMove
    jmp     .moveok
.notplayer:
    test    dword [rbx + MO_FLAGS], MF_MISSILE
    jz      .stopmove
    ; снаряд в небо -- исчезает
    mov     eax, [ceilingline]
    cmp     eax, -1
    je      .explode
    imul    eax, LINE_SIZE
    mov     ecx, [lines + rax + LN_BACKSEC]
    cmp     ecx, -1
    je      .explode
    imul    ecx, SECTOR_SIZE
    mov     edx, [sectors + rcx + SEC_CEILPIC]
    cmp     edx, [skyflatnum]
    jne     .explode
    mov     rcx, rbx
    call    P_RemoveMobj
    jmp     .done
.explode:
    mov     rcx, rbx
    call    P_ExplodeMissile
    jmp     .done
.stopmove:
    mov     dword [rbx + MO_MOMX], 0
    mov     dword [rbx + MO_MOMY], 0
.moveok:
    cmp     dword [rbx + MO_INUSE], 0
    je      .done
    mov     eax, r12d
    or      eax, r13d
    jnz     .steploop

    ; --- трение ---
    mov     eax, [rbx + MO_FLAGS]
    and     eax, MF_MISSILE|MF_SKULLFLY
    jnz     .done
    mov     eax, [rbx + MO_Z]
    cmp     eax, [rbx + MO_FLOORZ]
    jg      .done
    ; полная остановка при малой скорости
    mov     eax, [rbx + MO_MOMX]
    cmp     eax, -STOPSPEED
    jle     .fric
    cmp     eax, STOPSPEED
    jge     .fric
    mov     eax, [rbx + MO_MOMY]
    cmp     eax, -STOPSPEED
    jle     .fric
    cmp     eax, STOPSPEED
    jge     .fric
    ; игрок должен не давить на клавиши
    cmp     qword [rbx + MO_PLAYER], 0
    je      .stopnow
    mov     eax, [pl_forwardmove]
    or      eax, [pl_sidemove]
    jnz     .fric
    ; вернуть в стойку
    mov     rcx, rbx
    mov     edx, S_PLAY
    call    P_SetMobjState
.stopnow:
    mov     dword [rbx + MO_MOMX], 0
    mov     dword [rbx + MO_MOMY], 0
    jmp     .done
.fric:
    mov     ecx, [rbx + MO_MOMX]
    mov     edx, FRICTION
    call    FixedMul
    mov     [rbx + MO_MOMX], eax
    mov     ecx, [rbx + MO_MOMY]
    mov     edx, FRICTION
    call    FixedMul
    mov     [rbx + MO_MOMY], eax
.done:
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_ZMovement(rcx = mobj)
; ---------------------------------------------------------------------------
P_ZMovement:
    push    rbx
    push    rsi
    push    rdi
    mov     rbx, rcx
    ; плавный подъём по ступеням для игрока
    mov     rsi, [rbx + MO_PLAYER]
    test    rsi, rsi
    jz      .nostep
    mov     eax, [rbx + MO_Z]
    cmp     eax, [rbx + MO_FLOORZ]
    jge     .nostep
    mov     eax, [rbx + MO_FLOORZ]
    sub     eax, [rbx + MO_Z]
    sub     [rsi + PL_VIEWHEIGHT], eax
    mov     eax, VIEWHEIGHT
    sub     eax, [rsi + PL_VIEWHEIGHT]
    sar     eax, 3
    mov     [rsi + PL_DELTAVIEWHEIGHT], eax
.nostep:
    mov     eax, [rbx + MO_MOMZ]
    add     [rbx + MO_Z], eax

    ; --- парение к цели ---
    test    dword [rbx + MO_FLAGS], MF_FLOAT
    jz      .nofloat
    cmp     qword [rbx + MO_TARGET], 0
    je      .nofloat
    test    dword [rbx + MO_FLAGS], MF_SKULLFLY
    jnz     .nofloat
    test    dword [rbx + MO_FLAGS], MF_INFLOAT
    jnz     .nofloat
    mov     rdx, [rbx + MO_TARGET]
    mov     ecx, [rbx + MO_X]
    sub     ecx, [rdx + MO_X]
    mov     esi, [rbx + MO_Y]
    sub     esi, [rdx + MO_Y]
    push    rdx
    mov     edx, esi
    call    P_AproxDistance
    pop     rdx
    mov     esi, eax                    ; dist
    mov     edi, [rdx + MO_Z]
    mov     eax, [rbx + MO_HEIGHT]
    sar     eax, 1
    add     edi, eax
    sub     edi, [rbx + MO_Z]           ; delta
    test    edi, edi
    jns     .fup
    mov     eax, edi
    imul    eax, -3
    cmp     esi, eax
    jge     .nofloat
    sub     dword [rbx + MO_Z], FLOATSPEED
    jmp     .nofloat
.fup:
    jz      .nofloat
    mov     eax, edi
    imul    eax, 3
    cmp     esi, eax
    jge     .nofloat
    add     dword [rbx + MO_Z], FLOATSPEED
.nofloat:

    ; --- пол ---
    mov     eax, [rbx + MO_Z]
    cmp     eax, [rbx + MO_FLOORZ]
    jg      .abovefloor
    test    dword [rbx + MO_FLAGS], MF_SKULLFLY
    jz      .nobounce
    neg     dword [rbx + MO_MOMZ]
.nobounce:
    cmp     dword [rbx + MO_MOMZ], 0
    jge     .nofall
    mov     rsi, [rbx + MO_PLAYER]
    test    rsi, rsi
    jz      .nooof
    cmp     dword [rbx + MO_MOMZ], -GRAVITY*8
    jge     .nooof
    mov     eax, [rbx + MO_MOMZ]
    sar     eax, 3
    mov     [rsi + PL_DELTAVIEWHEIGHT], eax
    mov     rcx, rbx
    mov     edx, sfx_oof
    call    S_StartSound
.nooof:
    mov     dword [rbx + MO_MOMZ], 0
.nofall:
    mov     eax, [rbx + MO_FLOORZ]
    mov     [rbx + MO_Z], eax
    test    dword [rbx + MO_FLAGS], MF_MISSILE
    jz      .ceilchk
    test    dword [rbx + MO_FLAGS], MF_NOCLIP
    jnz     .ceilchk
    mov     rcx, rbx
    call    P_ExplodeMissile
    jmp     .done
.abovefloor:
    test    dword [rbx + MO_FLAGS], MF_NOGRAVITY
    jnz     .ceilchk
    cmp     dword [rbx + MO_MOMZ], 0
    jne     .grav
    mov     dword [rbx + MO_MOMZ], -GRAVITY*2
    jmp     .ceilchk
.grav:
    sub     dword [rbx + MO_MOMZ], GRAVITY
.ceilchk:
    mov     eax, [rbx + MO_Z]
    add     eax, [rbx + MO_HEIGHT]
    cmp     eax, [rbx + MO_CEILINGZ]
    jle     .done
    cmp     dword [rbx + MO_MOMZ], 0
    jle     .noclampz
    mov     dword [rbx + MO_MOMZ], 0
.noclampz:
    mov     eax, [rbx + MO_CEILINGZ]
    sub     eax, [rbx + MO_HEIGHT]
    mov     [rbx + MO_Z], eax
    test    dword [rbx + MO_FLAGS], MF_SKULLFLY
    jz      .nobounce2
    neg     dword [rbx + MO_MOMZ]
.nobounce2:
    test    dword [rbx + MO_FLAGS], MF_MISSILE
    jz      .done
    test    dword [rbx + MO_FLAGS], MF_NOCLIP
    jnz     .done
    mov     rcx, rbx
    call    P_ExplodeMissile
.done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_ExplodeMissile(rcx = mobj)
; ---------------------------------------------------------------------------
P_ExplodeMissile:
    push    rbx
    mov     rbx, rcx
    mov     dword [rbx + MO_MOMX], 0
    mov     dword [rbx + MO_MOMY], 0
    mov     dword [rbx + MO_MOMZ], 0
    mov     rdx, [rbx + MO_INFO]
    mov     edx, [rdx + MI_DEATHSTATE]
    mov     rcx, rbx
    call    P_SetMobjState
    cmp     dword [rbx + MO_INUSE], 0
    je      .done
    call    P_Random
    and     eax, 3
    sub     dword [rbx + MO_TICS], eax
    cmp     dword [rbx + MO_TICS], 1
    jge     .ticok
    mov     dword [rbx + MO_TICS], 1
.ticok:
    and     dword [rbx + MO_FLAGS], ~MF_MISSILE
    mov     rdx, [rbx + MO_INFO]
    mov     edx, [rdx + MI_DEATHSOUND]
    test    edx, edx
    jz      .done
    mov     rcx, rbx
    call    S_StartSound
.done:
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_SpawnPuff(ecx=x, edx=y, r8d=z)
; ---------------------------------------------------------------------------
P_SpawnPuff:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    mov     r12d, r8d
    push    rcx
    push    rdx
    call    P_SubRandom
    shl     eax, 10
    add     r12d, eax
    pop     rdx
    pop     rcx
    mov     r8d, r12d
    mov     r9d, MT_PUFF
    call    P_SpawnMobj
    test    rax, rax
    jz      .done
    mov     rbx, rax
    mov     dword [rbx + MO_MOMZ], FRACUNIT
    call    P_Random
    and     eax, 3
    sub     dword [rbx + MO_TICS], eax
    cmp     dword [rbx + MO_TICS], 1
    jge     .ok
    mov     dword [rbx + MO_TICS], 1
.ok:
    ; вблизи -- без первого кадра (как в DOOM для кулака)
    cmp     dword [attackrange], MELEERANGE
    jne     .done
    mov     rcx, rbx
    mov     edx, S_PUFF3
    call    P_SetMobjState
.done:
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_SpawnBlood(ecx=x, edx=y, r8d=z, r9d=урон)
; ---------------------------------------------------------------------------
P_SpawnBlood:
    push    rbx
    push    rsi
    push    r12
    mov     r12d, r9d
    mov     esi, r8d
    push    rcx
    push    rdx
    call    P_SubRandom
    shl     eax, 10
    add     esi, eax
    pop     rdx
    pop     rcx
    mov     r8d, esi
    mov     r9d, MT_BLOOD
    call    P_SpawnMobj
    test    rax, rax
    jz      .done
    mov     rbx, rax
    mov     dword [rbx + MO_MOMZ], FRACUNIT*2
    call    P_Random
    and     eax, 3
    sub     dword [rbx + MO_TICS], eax
    cmp     dword [rbx + MO_TICS], 1
    jge     .ok
    mov     dword [rbx + MO_TICS], 1
.ok:
    cmp     r12d, 12
    jge     .done
    cmp     r12d, 9
    jl      .small
    mov     rcx, rbx
    mov     edx, S_BLOOD2
    call    P_SetMobjState
    jmp     .done
.small:
    mov     rcx, rbx
    mov     edx, S_BLOOD3
    call    P_SetMobjState
.done:
    pop     r12
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_SpawnMissile(rcx = источник, rdx = цель, r8d = тип) -> rax
; ---------------------------------------------------------------------------
P_SpawnMissile:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    mov     rbx, rcx                    ; источник
    mov     rsi, rdx                    ; цель
    mov     r12d, r8d                   ; тип
    mov     ecx, [rbx + MO_X]
    mov     edx, [rbx + MO_Y]
    mov     r8d, [rbx + MO_Z]
    add     r8d, 4*8*FRACUNIT
    mov     r9d, r12d
    call    P_SpawnMobj
    test    rax, rax
    jz      .fail
    mov     r13, rax
    ; звук
    mov     rdx, [r13 + MO_INFO]
    mov     edx, [rdx + MI_SEESOUND]
    test    edx, edx
    jz      .nosnd
    mov     rcx, r13
    call    S_StartSound
.nosnd:
    mov     [r13 + MO_TARGET], rbx
    ; угол на цель
    mov     ecx, [rbx + MO_X]
    mov     edx, [rbx + MO_Y]
    mov     r8d, [rsi + MO_X]
    mov     r9d, [rsi + MO_Y]
    call    R_PointToAngle2
    mov     r14d, eax
    ; призрачные цели -- разброс
    test    dword [rsi + MO_FLAGS], MF_SHADOW
    jz      .noshadow
    call    P_SubRandom
    shl     eax, 20
    add     r14d, eax
.noshadow:
    mov     [r13 + MO_ANGLE], r14d
    mov     eax, r14d
    shr     eax, ANGLETOFINESHIFT
    and     eax, FINEMASK
    mov     rdx, [r13 + MO_INFO]
    mov     ecx, [rdx + MI_SPEED]
    mov     edx, [finecosine + rax*4]
    push    rax
    call    FixedMul
    mov     [r13 + MO_MOMX], eax
    pop     rax
    mov     rdx, [r13 + MO_INFO]
    mov     ecx, [rdx + MI_SPEED]
    mov     edx, [finesine + rax*4]
    call    FixedMul
    mov     [r13 + MO_MOMY], eax
    ; вертикальная составляющая
    mov     ecx, [rbx + MO_X]
    mov     edx, [rbx + MO_Y]
    mov     r8d, [rsi + MO_X]
    mov     r9d, [rsi + MO_Y]
    sub     r8d, ecx
    sub     r9d, edx
    mov     ecx, r8d
    mov     edx, r9d
    call    P_AproxDistance
    mov     rdx, [r13 + MO_INFO]
    mov     edx, [rdx + MI_SPEED]
    mov     ecx, eax
    call    FixedDiv                    ; dist / speed
    mov     edi, eax
    test    edi, edi
    jg      .distok
    mov     edi, 1
.distok:
    mov     eax, [rsi + MO_Z]
    sub     eax, [r13 + MO_Z]
    cdq
    idiv    edi
    mov     [r13 + MO_MOMZ], eax
    mov     rcx, r13
    call    P_CheckMissileSpawn
    mov     rax, r13
    jmp     .out
.fail:
    xor     eax, eax
.out:
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; P_CheckMissileSpawn(rcx = снаряд)
P_CheckMissileSpawn:
    push    rbx
    mov     rbx, rcx
    call    P_Random
    and     eax, 3
    shr     eax, 1
    sub     dword [rbx + MO_TICS], eax
    cmp     dword [rbx + MO_TICS], 1
    jge     .ok
    mov     dword [rbx + MO_TICS], 1
.ok:
    ; сдвиг на полшага, чтобы не застрять в стене
    mov     eax, [rbx + MO_MOMX]
    sar     eax, 1
    add     [rbx + MO_X], eax
    mov     eax, [rbx + MO_MOMY]
    sar     eax, 1
    add     [rbx + MO_Y], eax
    mov     eax, [rbx + MO_MOMZ]
    sar     eax, 1
    add     [rbx + MO_Z], eax
    mov     rcx, rbx
    mov     edx, [rbx + MO_X]
    mov     r8d, [rbx + MO_Y]
    call    P_TryMove
    test    eax, eax
    jnz     .done
    mov     rcx, rbx
    call    P_ExplodeMissile
.done:
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_SpawnPlayerMissile(rcx = игрок-mobj, edx = тип) -> rax
; ---------------------------------------------------------------------------
P_SpawnPlayerMissile:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    mov     rbx, rcx
    mov     r12d, edx
    ; автонаведение
    mov     r13d, [rbx + MO_ANGLE]
    mov     rcx, rbx
    mov     edx, r13d
    mov     r8d, 16*64*FRACUNIT
    call    P_AimLineAttack
    mov     edi, eax                    ; slope
    cmp     qword [linetarget], 0
    jne     .haveaim
    mov     rcx, rbx
    mov     edx, r13d
    add     edx, 1<<26
    mov     r8d, 16*64*FRACUNIT
    call    P_AimLineAttack
    mov     edi, eax
    cmp     qword [linetarget], 0
    jne     .aim2
    mov     rcx, rbx
    mov     edx, r13d
    sub     edx, 1<<26
    mov     r8d, 16*64*FRACUNIT
    call    P_AimLineAttack
    mov     edi, eax
    cmp     qword [linetarget], 0
    jne     .aim3
    mov     r13d, [rbx + MO_ANGLE]
    xor     edi, edi
    jmp     .haveaim
.aim2:
    add     r13d, 1<<26
    jmp     .haveaim
.aim3:
    sub     r13d, 1<<26
.haveaim:
    mov     ecx, [rbx + MO_X]
    mov     edx, [rbx + MO_Y]
    mov     r8d, [rbx + MO_Z]
    add     r8d, 4*8*FRACUNIT
    mov     r9d, r12d
    call    P_SpawnMobj
    test    rax, rax
    jz      .fail
    mov     rsi, rax
    mov     rdx, [rsi + MO_INFO]
    mov     edx, [rdx + MI_SEESOUND]
    test    edx, edx
    jz      .nosnd
    mov     rcx, rbx
    call    S_StartSound
.nosnd:
    mov     [rsi + MO_TARGET], rbx
    mov     [rsi + MO_ANGLE], r13d
    mov     eax, r13d
    shr     eax, ANGLETOFINESHIFT
    and     eax, FINEMASK
    mov     rdx, [rsi + MO_INFO]
    mov     ecx, [rdx + MI_SPEED]
    mov     edx, [finecosine + rax*4]
    push    rax
    call    FixedMul
    mov     [rsi + MO_MOMX], eax
    pop     rax
    mov     rdx, [rsi + MO_INFO]
    mov     ecx, [rdx + MI_SPEED]
    mov     edx, [finesine + rax*4]
    call    FixedMul
    mov     [rsi + MO_MOMY], eax
    mov     rdx, [rsi + MO_INFO]
    mov     ecx, [rdx + MI_SPEED]
    mov     edx, edi
    call    FixedMul
    mov     [rsi + MO_MOMZ], eax
    mov     rcx, rsi
    call    P_CheckMissileSpawn
    mov     rax, rsi
    jmp     .out
.fail:
    xor     eax, eax
.out:
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
