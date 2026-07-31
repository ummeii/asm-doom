; ===========================================================================
;  p_inter.asm -- подбор предметов, урон, смерть (порт p_inter.c)
; ===========================================================================

%define BASETHRESHOLD 100

; ---------------------------------------------------------------------------
;  P_GiveAmmo(ecx = вид, edx = сколько «обойм») -> eax (1 если взято)
; ---------------------------------------------------------------------------
P_GiveAmmo:
    push    rbx
    push    rsi
    cmp     ecx, am_noammo
    je      .no
    cmp     ecx, NUMAMMO
    jae     .no
    mov     ebx, ecx
    mov     eax, [player + PL_AMMO + rbx*4]
    cmp     eax, [player + PL_MAXAMMO + rbx*4]
    jge     .no
    ; количество
    test    edx, edx
    jz      .half
    mov     eax, [clipammo + rbx*4]
    imul    eax, edx
    jmp     .have
.half:
    mov     eax, [clipammo + rbx*4]
    sar     eax, 1
.have:
    mov     esi, eax
    ; на лёгких/сложных уровнях сложности -- двойной боезапас
    cmp     dword [gameskill], 0
    je      .dbl
    cmp     dword [gameskill], 4
    jne     .nodbl
.dbl:
    add     esi, esi
.nodbl:
    mov     eax, [player + PL_AMMO + rbx*4]
    mov     ecx, eax
    add     eax, esi
    cmp     eax, [player + PL_MAXAMMO + rbx*4]
    jle     .setok
    mov     eax, [player + PL_MAXAMMO + rbx*4]
.setok:
    mov     [player + PL_AMMO + rbx*4], eax
    ; автопереключение на подходящее оружие
    test    ecx, ecx
    jnz     .yes
    cmp     ebx, am_clip
    jne     .c2
    cmp     dword [player + PL_READYWEAPON], wp_fist
    jne     .yes
    cmp     dword [player + PL_WEAPONOWNED + wp_chaingun*4], 0
    je      .pistol
    mov     dword [player + PL_PENDINGWEAPON], wp_chaingun
    jmp     .yes
.pistol:
    mov     dword [player + PL_PENDINGWEAPON], wp_pistol
    jmp     .yes
.c2:
    cmp     ebx, am_shell
    jne     .c3
    cmp     dword [player + PL_READYWEAPON], wp_fist
    je      .shotchk
    cmp     dword [player + PL_READYWEAPON], wp_pistol
    jne     .yes
.shotchk:
    cmp     dword [player + PL_WEAPONOWNED + wp_shotgun*4], 0
    je      .yes
    mov     dword [player + PL_PENDINGWEAPON], wp_shotgun
    jmp     .yes
.c3:
    cmp     ebx, am_cell
    jne     .c4
    cmp     dword [player + PL_READYWEAPON], wp_fist
    je      .plaschk
    cmp     dword [player + PL_READYWEAPON], wp_pistol
    jne     .yes
.plaschk:
    cmp     dword [player + PL_WEAPONOWNED + wp_plasma*4], 0
    je      .yes
    mov     dword [player + PL_PENDINGWEAPON], wp_plasma
    jmp     .yes
.c4:
    cmp     dword [player + PL_READYWEAPON], wp_fist
    jne     .yes
    cmp     dword [player + PL_WEAPONOWNED + wp_missile*4], 0
    je      .yes
    mov     dword [player + PL_PENDINGWEAPON], wp_missile
.yes:
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
;  P_GiveWeapon(ecx = оружие, edx = выброшенное) -> eax
; ---------------------------------------------------------------------------
P_GiveWeapon:
    push    rbx
    push    rsi
    mov     ebx, ecx
    mov     esi, edx
    xor     r8d, r8d                    ; взято ли что-то
    imul    eax, ebx, WI_SIZE
    mov     ecx, [weaponinfo + rax + WI_AMMO]
    cmp     ecx, am_noammo
    je      .noammo
    push    rbx
    mov     edx, 2
    test    esi, esi
    jz      .fullammo
    mov     edx, 1
.fullammo:
    call    P_GiveAmmo
    pop     rbx
    mov     r8d, eax
.noammo:
    cmp     dword [player + PL_WEAPONOWNED + rbx*4], 0
    jne     .haveweap
    mov     dword [player + PL_WEAPONOWNED + rbx*4], 1
    mov     [player + PL_PENDINGWEAPON], ebx
    mov     r8d, 1
    test    esi, esi
    jnz     .haveweap
    mov     rcx, [playermo]
    mov     edx, sfx_wpnup
    call    S_StartSound
.haveweap:
    mov     eax, r8d
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_GiveBody(ecx = сколько) -> eax
; ---------------------------------------------------------------------------
P_GiveBody:
    cmp     dword [player + PL_HEALTH], 100
    jge     .no
    add     [player + PL_HEALTH], ecx
    cmp     dword [player + PL_HEALTH], 100
    jle     .ok
    mov     dword [player + PL_HEALTH], 100
.ok:
    mov     rax, [playermo]
    mov     ecx, [player + PL_HEALTH]
    mov     [rax + MO_HEALTH], ecx
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

; ---------------------------------------------------------------------------
;  P_GiveArmor(ecx = тип брони) -> eax
; ---------------------------------------------------------------------------
P_GiveArmor:
    mov     eax, ecx
    imul    eax, 100
    cmp     [player + PL_ARMORPOINTS], eax
    jge     .no
    mov     [player + PL_ARMORTYPE], ecx
    mov     [player + PL_ARMORPOINTS], eax
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

; ---------------------------------------------------------------------------
;  P_GiveCard(ecx = ключ)
; ---------------------------------------------------------------------------
P_GiveCard:
    cmp     dword [player + PL_CARDS + rcx*4], 0
    jne     .have
    mov     dword [player + PL_BONUSCOUNT], 6
    mov     dword [player + PL_CARDS + rcx*4], 1
.have:
    ret

; ---------------------------------------------------------------------------
;  P_GivePower(ecx = усиление) -> eax
; ---------------------------------------------------------------------------
P_GivePower:
    push    rbx
    mov     ebx, ecx
    cmp     ebx, pw_invulnerability
    jne     .n1
    mov     dword [player + PL_POWERS + rbx*4], INVULNTICS
    jmp     .yes
.n1:
    cmp     ebx, pw_invisibility
    jne     .n2
    mov     dword [player + PL_POWERS + rbx*4], INVISTICS
    mov     rax, [playermo]
    or      dword [rax + MO_FLAGS], MF_SHADOW
    jmp     .yes
.n2:
    cmp     ebx, pw_infrared
    jne     .n3
    mov     dword [player + PL_POWERS + rbx*4], INFRATICS
    jmp     .yes
.n3:
    cmp     ebx, pw_ironfeet
    jne     .n4
    mov     dword [player + PL_POWERS + rbx*4], IRONTICS
    jmp     .yes
.n4:
    cmp     ebx, pw_strength
    jne     .n5
    mov     ecx, 100
    call    P_GiveBody
    mov     dword [player + PL_POWERS + pw_strength*4], 1
    jmp     .yes
.n5:
    cmp     dword [player + PL_POWERS + rbx*4], 0
    jne     .no
    mov     dword [player + PL_POWERS + rbx*4], 1
.yes:
    mov     eax, 1
    pop     rbx
    ret
.no:
    xor     eax, eax
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_TouchSpecialThing(rcx = предмет, rdx = подобравший)
; ---------------------------------------------------------------------------
P_TouchSpecialThing:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    mov     rbx, rcx
    mov     rsi, rdx
    ; проверка по высоте
    mov     eax, [rbx + MO_Z]
    sub     eax, [rsi + MO_Z]
    cmp     eax, [rsi + MO_HEIGHT]
    jg      .done
    cmp     eax, -8*FRACUNIT
    jl      .done
    cmp     dword [rsi + MO_HEALTH], 0
    jle     .done

    mov     r12d, 1                     ; звук itemup по умолчанию
    mov     edi, [rbx + MO_TYPE]

    cmp     edi, MT_MISC_BON1
    jne     .t2
    inc     dword [player + PL_HEALTH]
    cmp     dword [player + PL_HEALTH], 200
    jle     .b1ok
    mov     dword [player + PL_HEALTH], 200
.b1ok:
    mov     eax, [player + PL_HEALTH]
    mov     [rsi + MO_HEALTH], eax
    jmp     .pickup
.t2:
    cmp     edi, MT_MISC_BON2
    jne     .t3
    inc     dword [player + PL_ARMORPOINTS]
    cmp     dword [player + PL_ARMORPOINTS], 200
    jle     .b2ok
    mov     dword [player + PL_ARMORPOINTS], 200
.b2ok:
    cmp     dword [player + PL_ARMORTYPE], 0
    jne     .pickup
    mov     dword [player + PL_ARMORTYPE], 1
    jmp     .pickup
.t3:
    cmp     edi, MT_MISC_SOUL
    jne     .t4
    add     dword [player + PL_HEALTH], 100
    cmp     dword [player + PL_HEALTH], 200
    jle     .s1ok
    mov     dword [player + PL_HEALTH], 200
.s1ok:
    mov     eax, [player + PL_HEALTH]
    mov     [rsi + MO_HEALTH], eax
    mov     r12d, 2
    jmp     .pickup
.t4:
    cmp     edi, MT_MISC_ARM1
    jne     .t5
    mov     ecx, 1
    call    P_GiveArmor
    test    eax, eax
    jz      .done
    jmp     .pickup
.t5:
    cmp     edi, MT_MISC_ARM2
    jne     .t6
    mov     ecx, 2
    call    P_GiveArmor
    test    eax, eax
    jz      .done
    jmp     .pickup
.t6:
    cmp     edi, MT_MISC_STIM
    jne     .t7
    mov     ecx, 10
    call    P_GiveBody
    test    eax, eax
    jz      .done
    jmp     .pickup
.t7:
    cmp     edi, MT_MISC_MEDI
    jne     .t8
    mov     ecx, 25
    call    P_GiveBody
    test    eax, eax
    jz      .done
    jmp     .pickup
.t8:
    cmp     edi, MT_MISC_BKEY
    jne     .t9
    mov     ecx, it_bluecard
    call    P_GiveCard
    jmp     .pickup
.t9:
    cmp     edi, MT_MISC_YKEY
    jne     .t10
    mov     ecx, it_yellowcard
    call    P_GiveCard
    jmp     .pickup
.t10:
    cmp     edi, MT_MISC_RKEY
    jne     .t11
    mov     ecx, it_redcard
    call    P_GiveCard
    jmp     .pickup
.t11:
    cmp     edi, MT_MISC_CLIP
    jne     .t12
    mov     ecx, am_clip
    mov     edx, 1
    test    dword [rbx + MO_FLAGS], MF_DROPPED
    jz      .clipfull
    xor     edx, edx
.clipfull:
    call    P_GiveAmmo
    test    eax, eax
    jz      .done
    jmp     .pickup
.t12:
    cmp     edi, MT_MISC_AMMO
    jne     .t13
    mov     ecx, am_clip
    mov     edx, 5
    call    P_GiveAmmo
    test    eax, eax
    jz      .done
    jmp     .pickup
.t13:
    cmp     edi, MT_MISC_SHEL
    jne     .t14
    mov     ecx, am_shell
    mov     edx, 1
    call    P_GiveAmmo
    test    eax, eax
    jz      .done
    jmp     .pickup
.t14:
    cmp     edi, MT_MISC_SBOX
    jne     .t15
    mov     ecx, am_shell
    mov     edx, 5
    call    P_GiveAmmo
    test    eax, eax
    jz      .done
    jmp     .pickup
.t15:
    cmp     edi, MT_MISC_ROCK
    jne     .t16
    mov     ecx, am_misl
    mov     edx, 1
    call    P_GiveAmmo
    test    eax, eax
    jz      .done
    jmp     .pickup
.t16:
    cmp     edi, MT_MISC_BROK
    jne     .t17
    mov     ecx, am_misl
    mov     edx, 5
    call    P_GiveAmmo
    test    eax, eax
    jz      .done
    jmp     .pickup
.t17:
    cmp     edi, MT_MISC_CELL
    jne     .t18
    mov     ecx, am_cell
    mov     edx, 1
    call    P_GiveAmmo
    test    eax, eax
    jz      .done
    jmp     .pickup
.t18:
    cmp     edi, MT_MISC_CELP
    jne     .t19
    mov     ecx, am_cell
    mov     edx, 5
    call    P_GiveAmmo
    test    eax, eax
    jz      .done
    jmp     .pickup
.t19:
    cmp     edi, MT_MISC_BPAK
    jne     .t20
    cmp     dword [player + PL_BACKPACK], 0
    jne     .bpdone
    mov     dword [player + PL_BACKPACK], 1
    xor     ecx, ecx
.bploop:
    mov     eax, [player + PL_MAXAMMO + rcx*4]
    add     eax, eax
    mov     [player + PL_MAXAMMO + rcx*4], eax
    inc     ecx
    cmp     ecx, NUMAMMO
    jb      .bploop
.bpdone:
    xor     ecx, ecx
.bpgive:
    push    rcx
    mov     edx, 1
    call    P_GiveAmmo
    pop     rcx
    inc     ecx
    cmp     ecx, NUMAMMO
    jb      .bpgive
    jmp     .pickup
.t20:
    cmp     edi, MT_MISC_SHOTGUN
    jne     .t21
    mov     ecx, wp_shotgun
    mov     edx, [rbx + MO_FLAGS]
    and     edx, MF_DROPPED
    call    P_GiveWeapon
    test    eax, eax
    jz      .done
    mov     r12d, 0
    jmp     .pickup
.t21:
    cmp     edi, MT_MISC_CHAINGUN
    jne     .t22
    mov     ecx, wp_chaingun
    xor     edx, edx
    call    P_GiveWeapon
    test    eax, eax
    jz      .done
    mov     r12d, 0
    jmp     .pickup
.t22:
    cmp     edi, MT_MISC_LAUNCHER
    jne     .t23
    mov     ecx, wp_missile
    xor     edx, edx
    call    P_GiveWeapon
    test    eax, eax
    jz      .done
    mov     r12d, 0
    jmp     .pickup
.t23:
    cmp     edi, MT_MISC_PLASMA
    jne     .t24
    mov     ecx, wp_plasma
    xor     edx, edx
    call    P_GiveWeapon
    test    eax, eax
    jz      .done
    mov     r12d, 0
    jmp     .pickup
.t24:
    cmp     edi, MT_MISC_BFG
    jne     .t25
    mov     ecx, wp_bfg
    xor     edx, edx
    call    P_GiveWeapon
    test    eax, eax
    jz      .done
    mov     r12d, 0
    jmp     .pickup
.t25:
    cmp     edi, MT_MISC_CHAINSAW
    jne     .t26
    mov     ecx, wp_chainsaw
    xor     edx, edx
    call    P_GiveWeapon
    test    eax, eax
    jz      .done
    mov     r12d, 0
    jmp     .pickup
.t26:
    cmp     edi, MT_MISC_INV
    jne     .t27
    mov     ecx, pw_invulnerability
    call    P_GivePower
    mov     r12d, 2
    jmp     .pickup
.t27:
    cmp     edi, MT_MISC_STR
    jne     .t28
    mov     ecx, pw_strength
    call    P_GivePower
    mov     dword [player + PL_PENDINGWEAPON], wp_fist
    mov     r12d, 2
    jmp     .pickup
.t28:
    cmp     edi, MT_MISC_INS
    jne     .t29
    mov     ecx, pw_invisibility
    call    P_GivePower
    mov     r12d, 2
    jmp     .pickup
.t29:
    cmp     edi, MT_MISC_SUIT
    jne     .t30
    mov     ecx, pw_ironfeet
    call    P_GivePower
    mov     r12d, 2
    jmp     .pickup
.t30:
    cmp     edi, MT_MISC_PMAP
    jne     .t31
    mov     ecx, pw_allmap
    call    P_GivePower
    mov     r12d, 2
    jmp     .pickup
.t31:
    cmp     edi, MT_MISC_PVIS
    jne     .done
    mov     ecx, pw_infrared
    call    P_GivePower
    mov     r12d, 2

.pickup:
    test    dword [rbx + MO_FLAGS], MF_COUNTITEM
    jz      .noitem
    inc     dword [player + PL_ITEMCOUNT]
.noitem:
    mov     rcx, rbx
    call    P_RemoveMobj
    add     dword [player + PL_BONUSCOUNT], 6
    test    r12d, r12d
    jz      .done
    mov     edx, sfx_itemup
    cmp     r12d, 2
    jne     .snd
    mov     edx, sfx_getpow
.snd:
    mov     rcx, [playermo]
    call    S_StartSound
.done:
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_KillMobj(rcx = источник, rdx = цель)
; ---------------------------------------------------------------------------
P_KillMobj:
    push    rbx
    push    rsi
    push    rdi
    mov     rsi, rcx                    ; источник
    mov     rbx, rdx                    ; цель
    and     dword [rbx + MO_FLAGS], ~(MF_SHOOTABLE|MF_FLOAT|MF_SKULLFLY)
    cmp     dword [rbx + MO_TYPE], MT_SKULL
    je      .noskull
    and     dword [rbx + MO_FLAGS], ~MF_NOGRAVITY
.noskull:
    or      dword [rbx + MO_FLAGS], MF_CORPSE|MF_DROPOFF
    sar     dword [rbx + MO_HEIGHT], 2
    ; счётчик убийств
    test    dword [rbx + MO_FLAGS], MF_COUNTKILL
    jz      .nocount
    inc     dword [player + PL_KILLCOUNT]
.nocount:
    ; смерть игрока
    cmp     qword [rbx + MO_PLAYER], 0
    je      .notplayer
    and     dword [rbx + MO_FLAGS], ~MF_SOLID
    mov     dword [player + PL_STATE], PST_DEAD
    call    P_DropWeapon
.notplayer:
    mov     rdx, [rbx + MO_INFO]
    mov     edx, [rdx + MI_DEATHSTATE]
    mov     rcx, rbx
    call    P_SetMobjState
    cmp     dword [rbx + MO_INUSE], 0
    je      .done
    call    P_Random
    and     eax, 3
    sub     [rbx + MO_TICS], eax
    cmp     dword [rbx + MO_TICS], 1
    jge     .ticok
    mov     dword [rbx + MO_TICS], 1
.ticok:
    ; выпадающие предметы
    mov     eax, [rbx + MO_TYPE]
    mov     edi, -1
    cmp     eax, MT_POSSESSED
    jne     .d1
    mov     edi, MT_MISC_CLIP
.d1:
    cmp     eax, MT_SHOTGUY
    jne     .d2
    mov     edi, MT_MISC_SHOTGUN
.d2:
    cmp     edi, -1
    je      .done
    mov     ecx, [rbx + MO_X]
    mov     edx, [rbx + MO_Y]
    mov     r8d, ONFLOORZ
    mov     r9d, edi
    call    P_SpawnMobj
    test    rax, rax
    jz      .done
    or      dword [rax + MO_FLAGS], MF_DROPPED
.done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_DamageMobj(rcx=цель, rdx=источник урона, r8=виновник, r9d=урон)
; ---------------------------------------------------------------------------
P_DamageMobj:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    mov     rbx, rcx                    ; цель
    mov     rsi, rdx                    ; inflictor
    mov     rdi, r8                     ; source
    mov     r12d, r9d                   ; урон
    test    dword [rbx + MO_FLAGS], MF_SHOOTABLE
    jz      .done
    cmp     dword [rbx + MO_HEALTH], 0
    jle     .done
    test    dword [rbx + MO_FLAGS], MF_SKULLFLY
    jz      .noskull
    mov     dword [rbx + MO_MOMX], 0
    mov     dword [rbx + MO_MOMY], 0
    mov     dword [rbx + MO_MOMZ], 0
.noskull:
    ; отбрасывание
    test    rsi, rsi
    jz      .nothrust
    test    dword [rbx + MO_FLAGS], MF_NOCLIP
    jnz     .nothrust
    mov     ecx, [rsi + MO_X]
    mov     edx, [rsi + MO_Y]
    mov     r8d, [rbx + MO_X]
    mov     r9d, [rbx + MO_Y]
    call    R_PointToAngle2
    mov     r13d, eax
    mov     eax, r12d
    imul    eax, FRACUNIT>>3
    imul    eax, 100
    mov     rdx, [rbx + MO_INFO]
    mov     ecx, [rdx + MI_MASS]
    test    ecx, ecx
    jnz     .massok
    mov     ecx, 100
.massok:
    cdq
    idiv    ecx
    mov     r14d, eax                   ; thrust
    mov     eax, r13d
    shr     eax, ANGLETOFINESHIFT
    and     eax, FINEMASK
    push    rax
    mov     ecx, r14d
    mov     edx, [finecosine + rax*4]
    call    FixedMul
    add     [rbx + MO_MOMX], eax
    pop     rax
    mov     ecx, r14d
    mov     edx, [finesine + rax*4]
    call    FixedMul
    add     [rbx + MO_MOMY], eax
.nothrust:
    ; игрок: броня
    cmp     qword [rbx + MO_PLAYER], 0
    je      .notplayer
    ; хак финала: в секторе со спецом 11 игрока нельзя добить
    mov     eax, [rbx + MO_SECTOR]
    imul    eax, SECTOR_SIZE
    cmp     dword [sectors + rax + SEC_SPECIAL], 11
    jne     .nohellhack
    cmp     r12d, [rbx + MO_HEALTH]
    jl      .nohellhack
    mov     r12d, [rbx + MO_HEALTH]
    dec     r12d
.nohellhack:
    ; ниже 1000 урон игнорируется в режиме бога и под неуязвимостью
    cmp     r12d, 1000
    jge     .nogod
    test    dword [player + PL_CHEATS], CF_GODMODE
    jnz     .done
    cmp     dword [player + PL_POWERS + pw_invulnerability*4], 0
    jne     .done
.nogod:
    cmp     dword [gameskill], 0        ; «я слишком молод, чтобы умирать»
    jne     .noeasy
    sar     r12d, 1
.noeasy:
    cmp     dword [player + PL_ARMORTYPE], 0
    je      .noarmor
    mov     eax, r12d
    cmp     dword [player + PL_ARMORTYPE], 1
    jne     .arm2
    xor     edx, edx
    mov     ecx, 3
    div     ecx
    jmp     .savedok
.arm2:
    sar     eax, 1
.savedok:
    mov     r13d, eax                   ; saved
    cmp     r13d, [player + PL_ARMORPOINTS]
    jl      .armok
    mov     r13d, [player + PL_ARMORPOINTS]
    mov     dword [player + PL_ARMORTYPE], 0
.armok:
    sub     [player + PL_ARMORPOINTS], r13d
    sub     r12d, r13d
.noarmor:
    sub     [player + PL_HEALTH], r12d
    cmp     dword [player + PL_HEALTH], 0
    jge     .hpok
    mov     dword [player + PL_HEALTH], 0
.hpok:
    mov     [player + PL_ATTACKER], rdi
    mov     [st_lastdmg], r12d
    add     [player + PL_DAMAGECOUNT], r12d
    cmp     dword [player + PL_DAMAGECOUNT], 100
    jle     .dcok
    mov     dword [player + PL_DAMAGECOUNT], 100
.dcok:
.notplayer:
    sub     [rbx + MO_HEALTH], r12d
    cmp     dword [rbx + MO_HEALTH], 0
    jg      .alive
    mov     rcx, rdi
    mov     rdx, rbx
    call    P_KillMobj
    jmp     .done
.alive:
    call    P_Random
    mov     rdx, [rbx + MO_INFO]
    cmp     eax, [rdx + MI_PAINCHANCE]
    jge     .nopain
    test    dword [rbx + MO_FLAGS], MF_SKULLFLY
    jnz     .nopain
    or      dword [rbx + MO_FLAGS], MF_JUSTHIT
    mov     rdx, [rbx + MO_INFO]
    mov     edx, [rdx + MI_PAINSTATE]
    test    edx, edx
    jz      .nopain
    mov     rcx, rbx
    call    P_SetMobjState
    cmp     dword [rbx + MO_INUSE], 0
    je      .done
.nopain:
    mov     dword [rbx + MO_REACTIONTIME], 0
    cmp     dword [rbx + MO_THRESHOLD], 0
    jne     .done
    test    rdi, rdi
    jz      .done
    cmp     rdi, rbx
    je      .done
    mov     [rbx + MO_TARGET], rdi
    mov     dword [rbx + MO_THRESHOLD], BASETHRESHOLD
    mov     rax, [rbx + MO_STATE]
    mov     rdx, [rbx + MO_INFO]
    mov     ecx, [rdx + MI_SPAWNSTATE]
    imul    ecx, STATE_SIZE
    lea     r8, [states]
    add     r8, rcx
    cmp     rax, r8
    jne     .done
    mov     edx, [rdx + MI_SEESTATE]
    test    edx, edx
    jz      .done
    mov     rcx, rbx
    call    P_SetMobjState
.done:
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
