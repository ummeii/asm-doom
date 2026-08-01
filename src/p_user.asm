; ===========================================================================
;  p_user.asm -- управление игроком, обзор, оружие в руках (p_user.c/p_pspr.c)
; ===========================================================================

%define MAXBOB      0x100000


%define LOWERSPEED   (FRACUNIT*6)
%define RAISESPEED   (FRACUNIT*6)
%define WEAPONBOTTOM (128*FRACUNIT)
%define WEAPONTOP    (32*FRACUNIT)

; ---------------------------------------------------------------------------
;  G_BuildTiccmd -- собрать команду из состояния клавиш
; ---------------------------------------------------------------------------
G_BuildTiccmd:
    push    rbx
    mov     dword [pl_forwardmove], 0
    mov     dword [pl_sidemove], 0
    mov     dword [pl_angleturn], 0
    mov     dword [pl_buttons], 0

    xor     ebx, ebx                    ; индекс скорости (бег)
    cmp     byte [g_keydown + K_RUN], 0
    je      .norun
    mov     ebx, 1
.norun:
    ; --- поворот ---
    cmp     byte [g_keydown + K_STRAFE], 0
    jne     .strafemode
    cmp     byte [g_keydown + K_STRAFE2], 0
    jne     .strafemode
    cmp     byte [g_keydown + K_LEFT], 0
    je      .nl
    mov     eax, [angleturn + rbx*4]
    add     [pl_angleturn], eax
.nl:
    cmp     byte [g_keydown + K_RIGHT], 0
    je      .nr
    mov     eax, [angleturn + rbx*4]
    sub     [pl_angleturn], eax
.nr:
    jmp     .turned
.strafemode:
    cmp     byte [g_keydown + K_LEFT], 0
    je      .sl
    mov     eax, [sidemovetab + rbx*4]
    sub     [pl_sidemove], eax
.sl:
    cmp     byte [g_keydown + K_RIGHT], 0
    je      .turned
    mov     eax, [sidemovetab + rbx*4]
    add     [pl_sidemove], eax
.turned:
    ; --- движение ---
    cmp     byte [g_keydown + K_FORWARD], 0
    je      .nf
    mov     eax, [forwardmovetab + rbx*4]
    add     [pl_forwardmove], eax
.nf:
    cmp     byte [g_keydown + K_UP], 0
    je      .nf2
    mov     eax, [forwardmovetab + rbx*4]
    add     [pl_forwardmove], eax
.nf2:
    cmp     byte [g_keydown + K_BACK], 0
    je      .nb
    mov     eax, [forwardmovetab + rbx*4]
    sub     [pl_forwardmove], eax
.nb:
    cmp     byte [g_keydown + K_DOWN], 0
    je      .nb2
    mov     eax, [forwardmovetab + rbx*4]
    sub     [pl_forwardmove], eax
.nb2:
    cmp     byte [g_keydown + K_STRAFER], 0
    je      .ns1
    mov     eax, [sidemovetab + rbx*4]
    add     [pl_sidemove], eax
.ns1:
    cmp     byte [g_keydown + K_STRAFEL], 0
    je      .ns2
    mov     eax, [sidemovetab + rbx*4]
    sub     [pl_sidemove], eax
.ns2:
    ; --- мышь ---
    mov     eax, [g_mousex]
    imul    eax, 8
    sub     [pl_angleturn], eax

    ; --- автоходьба (ключ -walk, только для проверки) ---
    cmp     byte [g_autowalk], 0
    je      .noauto
    mov     eax, [forwardmovetab]
    mov     [pl_forwardmove], eax
    mov     eax, [leveltime]            ; редкое нажатие "использовать"
    and     eax, 127
    cmp     eax, 3
    jge     .noauto
    or      dword [pl_buttons], BT_USE
.noauto:

    cmp     byte [g_autofire], 0
    je      .nofireauto
    or      dword [pl_buttons], BT_ATTACK
.nofireauto:

    ; --- кнопки ---
    cmp     byte [g_keydown + K_FIRE], 0
    jne     .fire
    cmp     byte [g_keydown + K_FIRE2], 0
    je      .nofire
.fire:
    or      dword [pl_buttons], BT_ATTACK
.nofire:
    cmp     byte [g_keydown + K_USE], 0
    jne     .use
    cmp     byte [g_keydown + K_USE2], 0
    je      .nouse
.use:
    or      dword [pl_buttons], BT_USE
.nouse:
    ; --- смена оружия ---
    xor     ebx, ebx
.wl:
    movzx   eax, byte [g_keyhit + K_W1 + rbx]
    test    eax, eax
    jz      .wnext
    mov     eax, [weaponkey + rbx*4]
    ; есть ли оружие
    cmp     dword [player + PL_WEAPONOWNED + rax*4], 0
    je      .wnext
    cmp     eax, [player + PL_READYWEAPON]
    je      .wnext
    mov     [pl_newweapon], eax
    or      dword [pl_buttons], BT_CHANGE
.wnext:
    inc     ebx
    cmp     ebx, 7
    jb      .wl
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_Thrust(rcx = mobj, edx = угол, r8d = сила)
; ---------------------------------------------------------------------------
P_Thrust:
    push    rbx
    push    rsi
    mov     rbx, rcx
    mov     esi, r8d
    shr     edx, ANGLETOFINESHIFT
    and     edx, FINEMASK
    push    rdx
    mov     ecx, esi
    mov     edx, [finecosine + rdx*4]
    call    FixedMul
    add     [rbx + MO_MOMX], eax
    pop     rdx
    mov     ecx, esi
    mov     edx, [finesine + rdx*4]
    call    FixedMul
    add     [rbx + MO_MOMY], eax
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_MovePlayer
; ---------------------------------------------------------------------------
P_MovePlayer:
    push    rbx
    mov     rbx, [playermo]
    mov     eax, [pl_angleturn]
    shl     eax, 16
    add     [rbx + MO_ANGLE], eax
    ; на земле?
    mov     eax, [rbx + MO_Z]
    cmp     eax, [rbx + MO_FLOORZ]
    jg      .notground
    cmp     dword [pl_forwardmove], 0
    je      .noforward
    mov     rcx, rbx
    mov     edx, [rbx + MO_ANGLE]
    mov     r8d, [pl_forwardmove]
    imul    r8d, 2048
    call    P_Thrust
.noforward:
    cmp     dword [pl_sidemove], 0
    je      .noside
    mov     rcx, rbx
    mov     edx, [rbx + MO_ANGLE]
    sub     edx, ANG90
    mov     r8d, [pl_sidemove]
    imul    r8d, 2048
    call    P_Thrust
.noside:
.notground:
    mov     eax, [pl_forwardmove]
    or      eax, [pl_sidemove]
    jz      .done
    mov     rax, [rbx + MO_STATE]
    lea     rcx, [states + S_PLAY*STATE_SIZE]
    cmp     rax, rcx
    jne     .done
    mov     rcx, rbx
    mov     edx, S_PLAY_RUN1
    call    P_SetMobjState
.done:
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_CalcHeight -- покачивание камеры
; ---------------------------------------------------------------------------
P_CalcHeight:
    push    rbx
    push    rsi
    mov     rbx, [playermo]
    mov     ecx, [rbx + MO_MOMX]
    mov     edx, ecx
    call    FixedMul
    mov     esi, eax
    mov     ecx, [rbx + MO_MOMY]
    mov     edx, ecx
    call    FixedMul
    add     eax, esi
    sar     eax, 2
    cmp     eax, MAXBOB
    jle     .bobok
    mov     eax, MAXBOB
.bobok:
    mov     [player + PL_BOB], eax
    ; в воздухе -- без покачивания
    mov     eax, [rbx + MO_Z]
    cmp     eax, [rbx + MO_FLOORZ]
    jle     .onground
    mov     eax, [rbx + MO_Z]
    add     eax, VIEWHEIGHT
    mov     [player + PL_VIEWZ], eax
    jmp     .clampceil
.onground:
    mov     eax, [leveltime]
    imul    eax, FINEANGLES/20
    and     eax, FINEMASK
    mov     ecx, [player + PL_BOB]
    sar     ecx, 1
    mov     edx, [finesine + rax*4]
    call    FixedMul
    mov     esi, eax                    ; bob
    cmp     dword [player + PL_STATE], PST_LIVE
    jne     .noview
    mov     eax, [player + PL_DELTAVIEWHEIGHT]
    add     [player + PL_VIEWHEIGHT], eax
    cmp     dword [player + PL_VIEWHEIGHT], VIEWHEIGHT
    jle     .vh1
    mov     dword [player + PL_VIEWHEIGHT], VIEWHEIGHT
    mov     dword [player + PL_DELTAVIEWHEIGHT], 0
.vh1:
    cmp     dword [player + PL_VIEWHEIGHT], VIEWHEIGHT/2
    jge     .vh2
    mov     dword [player + PL_VIEWHEIGHT], VIEWHEIGHT/2
    cmp     dword [player + PL_DELTAVIEWHEIGHT], 0
    jg      .vh2
    mov     dword [player + PL_DELTAVIEWHEIGHT], 1
.vh2:
    cmp     dword [player + PL_DELTAVIEWHEIGHT], 0
    je      .noview
    add     dword [player + PL_DELTAVIEWHEIGHT], FRACUNIT/4
    jnz     .noview
    mov     dword [player + PL_DELTAVIEWHEIGHT], 1
.noview:
    mov     eax, [rbx + MO_Z]
    add     eax, [player + PL_VIEWHEIGHT]
    add     eax, esi
    mov     [player + PL_VIEWZ], eax
.clampceil:
    mov     eax, [rbx + MO_CEILINGZ]
    sub     eax, 4*FRACUNIT
    cmp     [player + PL_VIEWZ], eax
    jle     .done
    mov     [player + PL_VIEWZ], eax
.done:
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_DeathThink
; ---------------------------------------------------------------------------
P_DeathThink:
    push    rbx
    push    rsi
    call    P_MovePsprites
    mov     rbx, [playermo]
    cmp     dword [player + PL_VIEWHEIGHT], 6*FRACUNIT
    jle     .vhok
    sub     dword [player + PL_VIEWHEIGHT], FRACUNIT
.vhok:
    mov     dword [player + PL_DELTAVIEWHEIGHT], 0
    call    P_CalcHeight
    ; поворот к убийце
    mov     rsi, [player + PL_ATTACKER]
    test    rsi, rsi
    jz      .noatk
    cmp     rsi, rbx
    je      .noatk
    mov     ecx, [rbx + MO_X]
    mov     edx, [rbx + MO_Y]
    mov     r8d, [rsi + MO_X]
    mov     r9d, [rsi + MO_Y]
    call    R_PointToAngle2
    mov     ecx, eax
    sub     ecx, [rbx + MO_ANGLE]
    cmp     ecx, ANG90/18
    jbe     .setang
    cmp     ecx, -(ANG90/18)
    jae     .setang
    cmp     ecx, ANG180
    jae     .turnleft
    add     dword [rbx + MO_ANGLE], ANG90/18
    jmp     .damage
.turnleft:
    sub     dword [rbx + MO_ANGLE], ANG90/18
    jmp     .damage
.setang:
    mov     [rbx + MO_ANGLE], eax
    cmp     dword [player + PL_DAMAGECOUNT], 0
    je      .damage
    dec     dword [player + PL_DAMAGECOUNT]
    jmp     .respawnchk
.noatk:
    cmp     dword [player + PL_DAMAGECOUNT], 0
    je      .respawnchk
    dec     dword [player + PL_DAMAGECOUNT]
    jmp     .respawnchk
.damage:
    cmp     dword [player + PL_DAMAGECOUNT], 0
    je      .respawnchk
    dec     dword [player + PL_DAMAGECOUNT]
.respawnchk:
    cmp     byte [g_keyhit + K_USE], 0
    jne     .respawn
    cmp     byte [g_keyhit + K_ENTER], 0
    jne     .respawn
    cmp     byte [g_keyhit + K_FIRE], 0
    je      .done
.respawn:
    mov     dword [player + PL_STATE], PST_REBORN
.done:
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_PlayerThink
; ---------------------------------------------------------------------------
P_PlayerThink:
    push    rbx
    push    rsi
    ; команда уже подставлена: своя из клавиш или пришедшая по сети
    mov     rbx, [playermo]
    test    rbx, rbx
    jz      .done

    cmp     dword [player + PL_STATE], PST_DEAD
    jne     .alive
    call    P_DeathThink
    jmp     .done
.alive:
    cmp     dword [rbx + MO_REACTIONTIME], 0
    je      .canmove
    dec     dword [rbx + MO_REACTIONTIME]
    jmp     .moved
.canmove:
    call    P_MovePlayer
.moved:
    call    P_CalcHeight
    ; спецэффект сектора (урон, секрет)
    mov     eax, [rbx + MO_SECTOR]
    cmp     eax, -1
    je      .nospec
    imul    eax, SECTOR_SIZE
    cmp     dword [sectors + rax + SEC_SPECIAL], 0
    je      .nospec
    call    P_PlayerInSpecialSector
.nospec:
    ; смена оружия
    test    dword [pl_buttons], BT_CHANGE
    jz      .nochange
    mov     eax, [pl_newweapon]
    mov     [player + PL_PENDINGWEAPON], eax
.nochange:
    ; использование
    test    dword [pl_buttons], BT_USE
    jz      .nouse
    cmp     dword [player + PL_USEDOWN], 0
    jne     .nouse2
    mov     rcx, rbx
    call    P_UseLines
    mov     dword [player + PL_USEDOWN], 1
.nouse2:
    jmp     .afteruse
.nouse:
    mov     dword [player + PL_USEDOWN], 0
.afteruse:
    call    P_MovePsprites

    ; --- счётчики усилений ---
    cmp     dword [player + PL_POWERS + pw_strength*4], 0
    je      .nostr
    inc     dword [player + PL_POWERS + pw_strength*4]
.nostr:
    cmp     dword [player + PL_POWERS + pw_invulnerability*4], 0
    je      .noinv
    dec     dword [player + PL_POWERS + pw_invulnerability*4]
.noinv:
    cmp     dword [player + PL_POWERS + pw_invisibility*4], 0
    je      .noins
    dec     dword [player + PL_POWERS + pw_invisibility*4]
    jnz     .noins
    and     dword [rbx + MO_FLAGS], ~MF_SHADOW
.noins:
    cmp     dword [player + PL_POWERS + pw_infrared*4], 0
    je      .noir
    dec     dword [player + PL_POWERS + pw_infrared*4]
.noir:
    cmp     dword [player + PL_POWERS + pw_ironfeet*4], 0
    je      .noif
    dec     dword [player + PL_POWERS + pw_ironfeet*4]
.noif:
    cmp     dword [player + PL_DAMAGECOUNT], 0
    je      .nodc
    dec     dword [player + PL_DAMAGECOUNT]
.nodc:
    cmp     dword [player + PL_BONUSCOUNT], 0
    je      .nobc
    dec     dword [player + PL_BONUSCOUNT]
.nobc:
    ; --- карта цветов ---
    mov     dword [player + PL_FIXEDCOLORMAP], 0
    mov     eax, [player + PL_POWERS + pw_invulnerability*4]
    test    eax, eax
    jz      .noinvmap
    cmp     eax, 4*32
    jg      .setinv
    test    eax, 8
    jz      .noinvmap
.setinv:
    mov     dword [player + PL_FIXEDCOLORMAP], INVERSECOLORMAP
.noinvmap:
    ; инфразрение
    mov     dword [player + PL_EXTRALIGHT], 0
    mov     eax, [player + PL_POWERS + pw_infrared*4]
    test    eax, eax
    jz      .done
    cmp     eax, 4*32
    jg      .setir
    test    eax, 8
    jz      .done
.setir:
    mov     dword [player + PL_EXTRALIGHT], 4
.done:
    pop     rsi
    pop     rbx
    ret

; ===========================================================================
;  Оружие в руках
; ===========================================================================

; P_SetPsprite(ecx = номер psprite, edx = состояние)
P_SetPsprite:
    push    rbx
    push    rsi
    push    rdi
    imul    ebx, ecx, PSPDEF_SIZE
    add     rbx, player + PL_PSPRITES
    mov     esi, edx
    mov     edi, ecx
.loop:
    test    esi, esi
    jnz     .have
    mov     qword [rbx + PSP_STATE], 0
    jmp     .done
.have:
    imul    eax, esi, STATE_SIZE
    lea     rdx, [states]
    add     rdx, rax
    mov     [rbx + PSP_STATE], rdx
    mov     eax, [rdx + ST_TICS]
    mov     [rbx + PSP_TICS], eax
    ; misc1/misc2 -- смещение оружия
    mov     eax, [rdx + ST_MISC1]
    test    eax, eax
    jz      .nomisc
    shl     eax, FRACBITS
    mov     [rbx + PSP_SX], eax
    mov     eax, [rdx + ST_MISC2]
    shl     eax, FRACBITS
    mov     [rbx + PSP_SY], eax
.nomisc:
    mov     eax, [rdx + ST_ACTION]
    test    eax, eax
    jz      .noaction
    lea     r8, [action_table]
    mov     r8, [r8 + rax*8]
    mov     rcx, player
    mov     rdx, rbx
    call    r8
    cmp     qword [rbx + PSP_STATE], 0
    je      .done
.noaction:
    mov     rdx, [rbx + PSP_STATE]
    mov     esi, [rdx + ST_NEXT]
    cmp     dword [rbx + PSP_TICS], 0
    je      .loop
.done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; P_BringUpWeapon
P_BringUpWeapon:
    push    rbx
    mov     eax, [player + PL_PENDINGWEAPON]
    cmp     eax, wp_nochange
    jne     .have
    mov     eax, [player + PL_READYWEAPON]
.have:
    cmp     eax, wp_chainsaw
    jne     .nosaw
    push    rax
    mov     rcx, [playermo]
    mov     edx, sfx_sawup
    call    S_StartSound
    pop     rax
.nosaw:
    mov     dword [player + PL_PENDINGWEAPON], wp_nochange
    mov     dword [player + PL_PSPRITES + ps_weapon*PSPDEF_SIZE + PSP_SY], WEAPONBOTTOM
    imul    ebx, eax, WI_SIZE
    mov     edx, [weaponinfo + rbx + WI_UPSTATE]
    xor     ecx, ecx
    call    P_SetPsprite
    pop     rbx
    ret

; P_CheckAmmo -> eax (1 если можно стрелять)
P_CheckAmmo:
    push    rbx
    mov     eax, [player + PL_READYWEAPON]
    imul    ebx, eax, WI_SIZE
    mov     ecx, [weaponinfo + rbx + WI_AMMO]
    mov     edx, 1                      ; сколько нужно
    cmp     eax, wp_bfg
    jne     .nobfg
    mov     edx, 40
.nobfg:
    cmp     eax, wp_supershotgun
    jne     .nossg
    mov     edx, 2
.nossg:
    cmp     ecx, am_noammo
    je      .ok
    mov     eax, [player + PL_AMMO + rcx*4]
    cmp     eax, edx
    jge     .ok
    ; выбираем другое оружие
    call    P_SelectWeapon
    mov     eax, [player + PL_READYWEAPON]
    imul    ebx, eax, WI_SIZE
    mov     edx, [weaponinfo + rbx + WI_DOWNSTATE]
    xor     ecx, ecx
    call    P_SetPsprite
    xor     eax, eax
    pop     rbx
    ret
.ok:
    mov     eax, 1
    pop     rbx
    ret

; выбрать лучшее доступное оружие
P_SelectWeapon:
    cmp     dword [player + PL_WEAPONOWNED + wp_plasma*4], 0
    je      .n1
    cmp     dword [player + PL_AMMO + am_cell*4], 0
    jle     .n1
    mov     dword [player + PL_PENDINGWEAPON], wp_plasma
    ret
.n1:
    cmp     dword [player + PL_WEAPONOWNED + wp_chaingun*4], 0
    je      .n2
    cmp     dword [player + PL_AMMO + am_clip*4], 0
    jle     .n2
    mov     dword [player + PL_PENDINGWEAPON], wp_chaingun
    ret
.n2:
    cmp     dword [player + PL_WEAPONOWNED + wp_shotgun*4], 0
    je      .n3
    cmp     dword [player + PL_AMMO + am_shell*4], 0
    jle     .n3
    mov     dword [player + PL_PENDINGWEAPON], wp_shotgun
    ret
.n3:
    cmp     dword [player + PL_AMMO + am_clip*4], 0
    jle     .n4
    mov     dword [player + PL_PENDINGWEAPON], wp_pistol
    ret
.n4:
    cmp     dword [player + PL_WEAPONOWNED + wp_chainsaw*4], 0
    je      .n5
    mov     dword [player + PL_PENDINGWEAPON], wp_chainsaw
    ret
.n5:
    cmp     dword [player + PL_WEAPONOWNED + wp_missile*4], 0
    je      .n6
    cmp     dword [player + PL_AMMO + am_misl*4], 0
    jle     .n6
    mov     dword [player + PL_PENDINGWEAPON], wp_missile
    ret
.n6:
    mov     dword [player + PL_PENDINGWEAPON], wp_fist
    ret

; P_FireWeapon
P_FireWeapon:
    push    rbx
    call    P_CheckAmmo
    test    eax, eax
    jz      .done
    mov     rcx, [playermo]
    mov     edx, S_PLAY_ATK1
    call    P_SetMobjState
    mov     eax, [player + PL_READYWEAPON]
    imul    ebx, eax, WI_SIZE
    mov     edx, [weaponinfo + rbx + WI_ATKSTATE]
    xor     ecx, ecx
    call    P_SetPsprite
.done:
    pop     rbx
    ret

; P_DropWeapon
P_DropWeapon:
    push    rbx
    mov     eax, [player + PL_READYWEAPON]
    imul    ebx, eax, WI_SIZE
    mov     edx, [weaponinfo + rbx + WI_DOWNSTATE]
    xor     ecx, ecx
    call    P_SetPsprite
    pop     rbx
    ret

; P_MovePsprites
P_MovePsprites:
    push    rbx
    push    rsi
    xor     esi, esi
.l:
    imul    ebx, esi, PSPDEF_SIZE
    add     rbx, player + PL_PSPRITES
    mov     rax, [rbx + PSP_STATE]
    test    rax, rax
    jz      .next
    cmp     dword [rbx + PSP_TICS], -1
    je      .next
    dec     dword [rbx + PSP_TICS]
    cmp     dword [rbx + PSP_TICS], 0
    jne     .next
    mov     rax, [rbx + PSP_STATE]
    mov     edx, [rax + ST_NEXT]
    mov     ecx, esi
    call    P_SetPsprite
.next:
    inc     esi
    cmp     esi, NUMPSPRITES
    jb      .l
    ; вспышка следует за оружием
    mov     eax, [player + PL_PSPRITES + ps_weapon*PSPDEF_SIZE + PSP_SX]
    mov     [player + PL_PSPRITES + ps_flash*PSPDEF_SIZE + PSP_SX], eax
    mov     eax, [player + PL_PSPRITES + ps_weapon*PSPDEF_SIZE + PSP_SY]
    mov     [player + PL_PSPRITES + ps_flash*PSPDEF_SIZE + PSP_SY], eax
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  Действия оружия: rcx = player, rdx = psp
; ---------------------------------------------------------------------------
A_WeaponReady_f:
    push    rbx
    push    rsi
    mov     rbx, rdx
    ; звук пилы
    mov     eax, [player + PL_READYWEAPON]
    cmp     eax, wp_chainsaw
    jne     .nosaw
    mov     rdx, [rbx + PSP_STATE]
    lea     rcx, [states + S_SAW*STATE_SIZE]
    cmp     rdx, rcx
    jne     .nosaw
    mov     rcx, [playermo]
    mov     edx, sfx_sawidl
    call    S_StartSound
.nosaw:
    ; смена оружия
    mov     eax, [player + PL_PENDINGWEAPON]
    cmp     eax, wp_nochange
    jne     .lower
    cmp     dword [player + PL_HEALTH], 0
    jg      .nolower
.lower:
    mov     eax, [player + PL_READYWEAPON]
    imul    esi, eax, WI_SIZE
    mov     edx, [weaponinfo + rsi + WI_DOWNSTATE]
    xor     ecx, ecx
    call    P_SetPsprite
    jmp     .done
.nolower:
    ; выстрел
    test    dword [pl_buttons], BT_ATTACK
    jz      .noattack
    cmp     dword [player + PL_ATTACKDOWN], 0
    jne     .refirecheck
    mov     dword [player + PL_ATTACKDOWN], 1
    call    P_FireWeapon
    jmp     .done
.refirecheck:
    mov     eax, [player + PL_READYWEAPON]
    cmp     eax, wp_missile
    je      .done
    cmp     eax, wp_bfg
    je      .done
    call    P_FireWeapon
    jmp     .done
.noattack:
    mov     dword [player + PL_ATTACKDOWN], 0
    ; покачивание
    mov     eax, [leveltime]
    and     eax, 63
    shl     eax, 19                     ; * FINEANGLES/64 << ANGLETOFINESHIFT
    shr     eax, ANGLETOFINESHIFT
    and     eax, FINEMASK
    push    rax
    mov     ecx, [player + PL_BOB]
    mov     edx, [finecosine + rax*4]
    call    FixedMul
    add     eax, FRACUNIT
    mov     [rbx + PSP_SX], eax
    pop     rax
    and     eax, FINEMASK/2
    mov     ecx, [player + PL_BOB]
    mov     edx, [finesine + rax*4]
    call    FixedMul
    add     eax, WEAPONTOP
    mov     [rbx + PSP_SY], eax
.done:
    pop     rsi
    pop     rbx
    ret

A_ReFire_f:
    push    rbx
    test    dword [pl_buttons], BT_ATTACK
    jz      .stop
    cmp     dword [player + PL_PENDINGWEAPON], wp_nochange
    jne     .stop
    cmp     dword [player + PL_HEALTH], 0
    jle     .stop
    inc     dword [player + PL_REFIRE]
    call    P_FireWeapon
    jmp     .done
.stop:
    mov     dword [player + PL_REFIRE], 0
    call    P_CheckAmmo
.done:
    pop     rbx
    ret

A_CheckReload_f:
    call    P_CheckAmmo
    ret

A_Lower_f:
    push    rbx
    mov     rbx, rdx
    add     dword [rbx + PSP_SY], LOWERSPEED
    cmp     dword [rbx + PSP_SY], WEAPONBOTTOM
    jl      .done
    cmp     dword [player + PL_STATE], PST_DEAD
    jne     .alive
    mov     dword [rbx + PSP_SY], WEAPONBOTTOM
    jmp     .done
.alive:
    cmp     dword [player + PL_HEALTH], 0
    jg      .ok
    xor     ecx, ecx
    xor     edx, edx
    call    P_SetPsprite
    jmp     .done
.ok:
    mov     eax, [player + PL_PENDINGWEAPON]
    cmp     eax, wp_nochange
    je      .nochg
    mov     [player + PL_READYWEAPON], eax
.nochg:
    call    P_BringUpWeapon
.done:
    pop     rbx
    ret

A_Raise_f:
    push    rbx
    mov     rbx, rdx
    sub     dword [rbx + PSP_SY], RAISESPEED
    cmp     dword [rbx + PSP_SY], WEAPONTOP
    jg      .done
    mov     dword [rbx + PSP_SY], WEAPONTOP
    mov     eax, [player + PL_READYWEAPON]
    imul    eax, WI_SIZE
    mov     edx, [weaponinfo + rax + WI_READYSTATE]
    xor     ecx, ecx
    call    P_SetPsprite
.done:
    pop     rbx
    ret

A_GunFlash_f:
    push    rbx
    mov     rcx, [playermo]
    mov     edx, S_PLAY_ATK1
    call    P_SetMobjState
    mov     eax, [player + PL_READYWEAPON]
    imul    eax, WI_SIZE
    mov     edx, [weaponinfo + rax + WI_FLASHSTATE]
    mov     ecx, ps_flash
    call    P_SetPsprite
    pop     rbx
    ret

A_Light0_f:
    mov     dword [player + PL_EXTRALIGHT], 0
    ret
A_Light1_f:
    mov     dword [player + PL_EXTRALIGHT], 1
    ret
A_Light2_f:
    mov     dword [player + PL_EXTRALIGHT], 2
    ret

; --- прицеливание для пуль ---
P_BulletSlope:
    push    rbx
    push    rsi
    mov     rbx, [playermo]
    mov     esi, [rbx + MO_ANGLE]
    mov     rcx, rbx
    mov     edx, esi
    mov     r8d, 16*64*FRACUNIT
    call    P_AimLineAttack
    mov     [bulletslope], eax
    cmp     qword [linetarget], 0
    jne     .done
    mov     rcx, rbx
    mov     edx, esi
    add     edx, 1<<26
    mov     r8d, 16*64*FRACUNIT
    call    P_AimLineAttack
    mov     [bulletslope], eax
    cmp     qword [linetarget], 0
    jne     .done
    mov     rcx, rbx
    mov     edx, esi
    sub     edx, 1<<26
    mov     r8d, 16*64*FRACUNIT
    call    P_AimLineAttack
    mov     [bulletslope], eax
.done:
    pop     rsi
    pop     rbx
    ret

; P_GunShot(ecx = точность)
P_GunShot:
    push    rbx
    push    rsi
    mov     rbx, [playermo]
    mov     esi, [rbx + MO_ANGLE]
    test    ecx, ecx
    jnz     .accurate
    call    P_SubRandom
    shl     eax, 18
    add     esi, eax
.accurate:
    call    P_Random
    xor     edx, edx
    mov     ecx, 3
    div     ecx
    inc     edx
    imul    edx, 5
    mov     [la_damage], edx
    mov     rcx, rbx
    mov     edx, esi
    mov     r8d, MISSILERANGE
    mov     r9d, [bulletslope]
    call    P_LineAttack
    pop     rsi
    pop     rbx
    ret

A_FirePistol_f:
    push    rbx
    mov     rcx, [playermo]
    mov     edx, sfx_pistol
    call    S_StartSound
    mov     rcx, [playermo]
    mov     edx, S_PLAY_ATK1
    call    P_SetMobjState
    mov     eax, [player + PL_READYWEAPON]
    imul    eax, WI_SIZE
    mov     ecx, [weaponinfo + rax + WI_AMMO]
    dec     dword [player + PL_AMMO + rcx*4]
    mov     eax, [player + PL_READYWEAPON]
    imul    eax, WI_SIZE
    mov     edx, [weaponinfo + rax + WI_FLASHSTATE]
    mov     ecx, ps_flash
    call    P_SetPsprite
    call    P_BulletSlope
    mov     ecx, [player + PL_REFIRE]
    xor     eax, eax
    test    ecx, ecx
    sete    al
    mov     ecx, eax
    call    P_GunShot
    pop     rbx
    ret

A_FireShotgun_f:
    push    rbx
    push    rsi
    mov     rcx, [playermo]
    mov     edx, sfx_shotgn
    call    S_StartSound
    mov     rcx, [playermo]
    mov     edx, S_PLAY_ATK1
    call    P_SetMobjState
    mov     eax, [player + PL_READYWEAPON]
    imul    eax, WI_SIZE
    mov     ecx, [weaponinfo + rax + WI_AMMO]
    dec     dword [player + PL_AMMO + rcx*4]
    mov     eax, [player + PL_READYWEAPON]
    imul    eax, WI_SIZE
    mov     edx, [weaponinfo + rax + WI_FLASHSTATE]
    mov     ecx, ps_flash
    call    P_SetPsprite
    call    P_BulletSlope
    mov     esi, 7
.pellet:
    xor     ecx, ecx
    call    P_GunShot
    dec     esi
    jnz     .pellet
    pop     rsi
    pop     rbx
    ret

A_FireCGun_f:
    push    rbx
    mov     rcx, [playermo]
    mov     edx, sfx_pistol
    call    S_StartSound
    mov     eax, [player + PL_READYWEAPON]
    imul    eax, WI_SIZE
    mov     ecx, [weaponinfo + rax + WI_AMMO]
    cmp     dword [player + PL_AMMO + rcx*4], 0
    jle     .done
    dec     dword [player + PL_AMMO + rcx*4]
    mov     rcx, [playermo]
    mov     edx, S_PLAY_ATK1
    call    P_SetMobjState
    mov     eax, [player + PL_READYWEAPON]
    imul    eax, WI_SIZE
    mov     edx, [weaponinfo + rax + WI_FLASHSTATE]
    mov     ecx, ps_flash
    call    P_SetPsprite
    call    P_BulletSlope
    mov     ecx, [player + PL_REFIRE]
    xor     eax, eax
    test    ecx, ecx
    sete    al
    mov     ecx, eax
    call    P_GunShot
.done:
    pop     rbx
    ret

A_FireMissile_f:
    push    rbx
    mov     eax, [player + PL_READYWEAPON]
    imul    eax, WI_SIZE
    mov     ecx, [weaponinfo + rax + WI_AMMO]
    dec     dword [player + PL_AMMO + rcx*4]
    mov     rcx, [playermo]
    mov     edx, MT_ROCKET
    call    P_SpawnPlayerMissile
    pop     rbx
    ret

A_FirePlasma_f:
    push    rbx
    mov     eax, [player + PL_READYWEAPON]
    imul    eax, WI_SIZE
    mov     ecx, [weaponinfo + rax + WI_AMMO]
    dec     dword [player + PL_AMMO + rcx*4]
    mov     eax, [player + PL_READYWEAPON]
    imul    eax, WI_SIZE
    mov     edx, [weaponinfo + rax + WI_FLASHSTATE]
    mov     ecx, ps_flash
    call    P_SetPsprite
    mov     rcx, [playermo]
    mov     edx, MT_PLASMA
    call    P_SpawnPlayerMissile
    pop     rbx
    ret

A_FireBFG_f:
    push    rbx
    mov     eax, [player + PL_READYWEAPON]
    imul    eax, WI_SIZE
    mov     ecx, [weaponinfo + rax + WI_AMMO]
    sub     dword [player + PL_AMMO + rcx*4], 40
    mov     rcx, [playermo]
    mov     edx, MT_BFG
    call    P_SpawnPlayerMissile
    pop     rbx
    ret

A_BFGSpray_f:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    mov     rbx, rcx                    ; сам заряд
    xor     esi, esi
.l:
    mov     eax, [rbx + MO_ANGLE]
    sub     eax, ANG90/2
    mov     ecx, esi
    imul    ecx, ANG90/40
    add     eax, ecx
    push    rax
    mov     rcx, [rbx + MO_TARGET]
    test    rcx, rcx
    jz      .skip1
    mov     edx, eax
    mov     r8d, 16*64*FRACUNIT
    call    P_AimLineAttack
.skip1:
    pop     rax
    cmp     qword [linetarget], 0
    je      .next
    mov     rdi, [linetarget]
    mov     ecx, [rdi + MO_X]
    mov     edx, [rdi + MO_Y]
    mov     r8d, [rdi + MO_Z]
    mov     r9d, [rdi + MO_HEIGHT]
    sar     r9d, 2
    add     r8d, r9d
    mov     r9d, MT_TFOG
    call    P_SpawnMobj
    xor     r12d, r12d
    mov     ecx, 15
.dmg:
    push    rcx
    call    P_Random
    and     eax, 7
    inc     eax
    add     r12d, eax
    pop     rcx
    dec     ecx
    jnz     .dmg
    mov     rcx, rdi
    mov     rdx, [rbx + MO_TARGET]
    mov     r8, [rbx + MO_TARGET]
    mov     r9d, r12d
    call    P_DamageMobj
.next:
    inc     esi
    cmp     esi, 40
    jb      .l
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

A_Punch_f:
    push    rbx
    push    rsi
    push    rdi
    call    P_Random
    xor     edx, edx
    mov     ecx, 10
    div     ecx
    inc     edx
    imul    edx, 2
    cmp     dword [player + PL_POWERS + pw_strength*4], 0
    je      .nostr
    imul    edx, 10
.nostr:
    mov     [la_damage], edx
    mov     rbx, [playermo]
    mov     esi, [rbx + MO_ANGLE]
    call    P_SubRandom
    shl     eax, 18
    add     esi, eax
    mov     rcx, rbx
    mov     edx, esi
    mov     r8d, MELEERANGE
    call    P_AimLineAttack
    mov     edi, eax
    mov     rcx, rbx
    mov     edx, esi
    mov     r8d, MELEERANGE
    mov     r9d, edi
    call    P_LineAttack
    cmp     qword [linetarget], 0
    je      .done
    mov     rcx, rbx
    mov     edx, sfx_punch
    call    S_StartSound
    mov     rdx, [linetarget]
    mov     ecx, [rbx + MO_X]
    mov     r8d, [rdx + MO_X]
    mov     r9d, [rdx + MO_Y]
    mov     edx, [rbx + MO_Y]
    call    R_PointToAngle2
    mov     [rbx + MO_ANGLE], eax
.done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

A_Saw_f:
    push    rbx
    push    rsi
    push    rdi
    call    P_Random
    and     eax, 15
    inc     eax
    imul    eax, 2
    mov     [la_damage], eax
    mov     rbx, [playermo]
    mov     esi, [rbx + MO_ANGLE]
    call    P_SubRandom
    shl     eax, 18
    add     esi, eax
    mov     rcx, rbx
    mov     edx, esi
    mov     r8d, MELEERANGE+1
    call    P_AimLineAttack
    mov     edi, eax
    mov     rcx, rbx
    mov     edx, esi
    mov     r8d, MELEERANGE+1
    mov     r9d, edi
    call    P_LineAttack
    cmp     qword [linetarget], 0
    jne     .hit
    mov     rcx, rbx
    mov     edx, sfx_sawful
    call    S_StartSound
    jmp     .done
.hit:
    mov     rcx, rbx
    mov     edx, sfx_sawhit
    call    S_StartSound
.done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret
