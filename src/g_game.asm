; ===========================================================================
;  g_game.asm -- запуск уровня, игровой тик, вывод кадра
; ===========================================================================

; ---------------------------------------------------------------------------
;  G_InitNew
; ---------------------------------------------------------------------------
G_InitNew:
    push    rbx
    mov     dword [gameskill], 2
    cmp     byte [g_haveskill], 0
    je      .defskill
    movzx   eax, byte [g_startskill]
    mov     [gameskill], eax
.defskill:
    mov     eax, [gameskill]
    mov     [m_item], eax
    mov     dword [prndseed], 1993
    mov     al, [g_startlevel]
    mov     [g_curlevel], al
    call    G_LoadLevel
    mov     byte [g_gamestate], 0       ; стартуем с меню
    ; тестовые ключи запускают игру сразу
    mov     al, [g_autowalk]
    or      al, [g_autofire]
    or      al, [g_automap0]
    or      al, [g_haveskill]
    jz      .noauto
    mov     byte [g_gamestate], 1
    mov     al, [g_automap0]
    test    al, al
    jz      .noauto
    mov     dword [player + PL_POWERS + pw_allmap*4], 1
    call    AM_Start
.noauto:
    pop     rbx
    ret

G_LoadLevel:
    push    rbx
    call    D_InitPlayers
    call    G_SetFastParms
    call    P_InitMobjs
    mov     dword [leveltime], 0
    mov     dword [totalkills], 0
    mov     dword [totalitems], 0
    movzx   eax, byte [g_curlevel]
    lea     rcx, [levellist]
    mov     rcx, [rcx + rax*8]
    call    P_SetupLevel
    call    P_InitSpecials
    call    P_SpawnThings
    call    G_PlayerReborn
    ; окно уже держит своего игрока -- связываем с ним ячейку массива
    mov     eax, [consoleplayer]
    mov     [curplayer], eax
    mov     rcx, [playermo]
    mov     [playermos + rax*8], rcx
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  G_NextLevel -- перейти на следующую карту (после экрана статистики)
; ---------------------------------------------------------------------------
G_NextLevel:
    push    rbx
    movzx   eax, byte [g_curlevel]
    inc     eax
    cmp     eax, NUMLEVELS
    jb      .ok
    xor     eax, eax
.ok:
    mov     [g_curlevel], al
    call    G_LoadLevel
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  G_SetFastParms -- «кошмар» ускоряет демонов и снаряды (как G_SetFastParms)
; ---------------------------------------------------------------------------
G_SetFastParms:
    push    rbx
    ; респавн монстров только на кошмаре
    xor     eax, eax
    cmp     dword [gameskill], 4
    sete    al
    mov     [respawnmonsters], eax
    cmp     [fastparm], eax
    je      .done                       ; режим не изменился
    mov     [fastparm], eax
    test    eax, eax
    jz      .slow
    ; вдвое короче кадры бега и боли демона
    mov     ebx, S_SARG_RUN1
.fastl:
    imul    eax, ebx, STATE_SIZE
    sar     dword [states + rax + ST_TICS], 1
    inc     ebx
    cmp     ebx, S_SARG_PAIN2
    jbe     .fastl
    ; и вдвое быстрее снаряды
    mov     eax, 20*FRACUNIT
    mov     [mobjinfo + MT_TROOPSHOT*MOBJINFO_SIZE + MI_SPEED], eax
    mov     [mobjinfo + MT_BRUISERSHOT*MOBJINFO_SIZE + MI_SPEED], eax
    jmp     .done
.slow:
    mov     ebx, S_SARG_RUN1
.slowl:
    imul    eax, ebx, STATE_SIZE
    shl     dword [states + rax + ST_TICS], 1
    inc     ebx
    cmp     ebx, S_SARG_PAIN2
    jbe     .slowl
    mov     eax, 10*FRACUNIT
    mov     [mobjinfo + MT_TROOPSHOT*MOBJINFO_SIZE + MI_SPEED], eax
    mov     [mobjinfo + MT_BRUISERSHOT*MOBJINFO_SIZE + MI_SPEED], eax
.done:
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  G_PlayerReborn -- начальное снаряжение
; ---------------------------------------------------------------------------
G_PlayerReborn:
    push    rbx
    mov     dword [player + PL_HEALTH], 100
    mov     dword [player + PL_CHEATS], 0
    cmp     byte [g_godmode], 0
    je      .nogod
    mov     dword [player + PL_CHEATS], CF_GODMODE
.nogod:
    mov     dword [player + PL_STATE], PST_LIVE
    mov     dword [player + PL_ARMORPOINTS], 0
    mov     dword [player + PL_ARMORTYPE], 0
    mov     dword [player + PL_VIEWHEIGHT], VIEWHEIGHT
    mov     dword [player + PL_DELTAVIEWHEIGHT], 0
    mov     dword [player + PL_DAMAGECOUNT], 0
    mov     dword [player + PL_BONUSCOUNT], 0
    mov     dword [player + PL_EXTRALIGHT], 0
    mov     dword [player + PL_FIXEDCOLORMAP], 0
    mov     dword [player + PL_BACKPACK], 0
    mov     qword [player + PL_MESSAGE], 0
    mov     qword [player + PL_ATTACKER], 0
    xor     ebx, ebx
.clr:
    mov     dword [player + PL_WEAPONOWNED + rbx*4], 0
    mov     dword [player + PL_POWERS + rbx*4], 0
    mov     dword [player + PL_CARDS + rbx*4], 0
    inc     ebx
    cmp     ebx, NUMWEAPONS
    jb      .clr
    xor     ebx, ebx
.clr2:
    mov     dword [player + PL_AMMO + rbx*4], 0
    mov     eax, [maxammostart + rbx*4]
    mov     [player + PL_MAXAMMO + rbx*4], eax
    inc     ebx
    cmp     ebx, NUMAMMO
    jb      .clr2
    mov     dword [player + PL_WEAPONOWNED + wp_fist*4], 1
    mov     dword [player + PL_WEAPONOWNED + wp_pistol*4], 1
    mov     dword [player + PL_AMMO + am_clip*4], 50
    mov     dword [player + PL_READYWEAPON], wp_pistol
    mov     dword [player + PL_PENDINGWEAPON], wp_pistol
    mov     dword [player + PL_KILLCOUNT], 0
    mov     dword [player + PL_ITEMCOUNT], 0
    mov     dword [player + PL_SECRETCOUNT], 0
    xor     ebx, ebx
.clrpsp:
    imul    eax, ebx, PSPDEF_SIZE
    add     rax, player + PL_PSPRITES
    mov     qword [rax + PSP_STATE], 0
    inc     ebx
    cmp     ebx, NUMPSPRITES
    jb      .clrpsp
    call    P_BringUpWeapon
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_SpawnThings -- размещение объектов уровня
; ---------------------------------------------------------------------------
P_SpawnThings:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    xor     ebx, ebx
.l:
    cmp     ebx, [numthings]
    jae     .done
    imul    r12d, ebx, THINGDEF_SIZE
    mov     eax, [thingdefs + r12 + TH_TYPE]
    cmp     eax, 1
    jne     .other
    ; --- старт игрока ---
    mov     ecx, [thingdefs + r12 + TH_X]
    shl     ecx, 16
    mov     edx, [thingdefs + r12 + TH_Y]
    shl     edx, 16
    mov     r8d, ONFLOORZ
    mov     r9d, MT_PLAYER
    call    P_SpawnMobj
    test    rax, rax
    jz      .next
    mov     [playermo], rax
    mov     [player + PL_MO], rax
    mov     ecx, [thingdefs + r12 + TH_ANGLE]
    imul    ecx, ANG1
    mov     [rax + MO_ANGLE], ecx
    mov     qword [rax + MO_PLAYER], player
    mov     ecx, [rax + MO_Z]
    add     ecx, VIEWHEIGHT
    mov     [player + PL_VIEWZ], ecx
    jmp     .next
.other:
    ; --- фильтр по сложности, как в P_SpawnMapThing ---
    mov     ecx, [thingdefs + r12 + TH_FLAGS]
    test    ecx, MTF_NOTSINGLE          ; только для сетевой игры
    jnz     .next
    mov     edx, [gameskill]
    cmp     edx, 0
    jne     .sk1
    mov     edx, MTF_EASY
    jmp     .skbit
.sk1:
    cmp     edx, 4
    jne     .skmid
    mov     edx, MTF_HARD               ; на кошмаре набор как на ультра-насилии
    jmp     .skbit
.skmid:
    dec     edx
    mov     r8d, 1
    xchg    ecx, edx
    shl     r8d, cl
    xchg    ecx, edx
    mov     edx, r8d
.skbit:
    test    edx, ecx
    jz      .next
    ; ищем тип по doomednum
    xor     edi, edi
.find:
    cmp     edi, NUMMOBJTYPES
    jae     .next
    imul    esi, edi, MOBJINFO_SIZE
    cmp     [mobjinfo + rsi + MI_DOOMEDNUM], eax
    je      .found
    inc     edi
    jmp     .find
.found:
    mov     ecx, [thingdefs + r12 + TH_X]
    shl     ecx, 16
    mov     edx, [thingdefs + r12 + TH_Y]
    shl     edx, 16
    mov     r8d, ONFLOORZ
    imul    esi, edi, MOBJINFO_SIZE
    test    dword [mobjinfo + rsi + MI_FLAGS], MF_SPAWNCEILING
    jz      .floorspawn
    mov     r8d, ONCEILINGZ
.floorspawn:
    mov     r9d, edi
    call    P_SpawnMobj
    test    rax, rax
    jz      .next
    mov     ecx, [thingdefs + r12 + TH_ANGLE]
    imul    ecx, ANG1
    mov     [rax + MO_ANGLE], ecx
    ; точка появления -- для респавна монстров на «кошмаре»
    mov     ecx, [thingdefs + r12 + TH_X]
    mov     [rax + MO_SPAWNX], ecx
    mov     ecx, [thingdefs + r12 + TH_Y]
    mov     [rax + MO_SPAWNY], ecx
    mov     ecx, [thingdefs + r12 + TH_ANGLE]
    mov     [rax + MO_SPAWNANG], ecx
    mov     ecx, [thingdefs + r12 + TH_TYPE]
    mov     [rax + MO_SPAWNTYPE], ecx
    mov     ecx, [thingdefs + r12 + TH_FLAGS]
    test    ecx, MTF_AMBUSH             ; засада
    jz      .noambush
    or      dword [rax + MO_FLAGS], MF_AMBUSH
.noambush:
    test    dword [rax + MO_FLAGS], MF_COUNTKILL
    jz      .nokill
    inc     dword [totalkills]
.nokill:
    test    dword [rax + MO_FLAGS], MF_COUNTITEM
    jz      .next
    inc     dword [totalitems]
.next:
    inc     ebx
    jmp     .l
.done:
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  G_Ticker
; ---------------------------------------------------------------------------
G_Ticker:
    push    rbx
    cmp     dword [wipe_state], WIPE_OFF
    jne     .done                       ; пока экран плавится, игра стоит
    cmp     byte [g_gamestate], 2
    jne     .notwi
    call    WI_Ticker
    jmp     .done
.notwi:
    cmp     byte [g_gamestate], 0
    jne     .level
    call    M_Ticker
    jmp     .done
.level:
    ; в меню по Esc
    cmp     byte [g_keyhit + K_ESC], 0
    je      .noesc
    mov     byte [g_gamestate], 0
    mov     byte [am_active], 0
    jmp     .done
.noesc:
    ; автокарта
    cmp     byte [g_keyhit + K_MAP], 0
    je      .nomap
    xor     byte [am_active], 1
    cmp     byte [am_active], 0
    je      .nomap
    call    AM_Start
.nomap:
    call    AM_Ticker
    call    ST_Ticker
    ; переключение захвата мыши
    cmp     byte [g_keyhit + K_MOUSETOG], 0
    je      .nomouse
    xor     byte [g_mousegrab], 1
.nomouse:
    cmp     qword [playermo], 0
    je      .done

    ; своя команда с клавиш -> общий буфер, затем тик всех игроков
    call    G_BuildTiccmd
    mov     ecx, [consoleplayer]
    call    D_StoreCmd
    call    D_RunPlayers
    call    P_RunThinkers
    call    P_UpdateSpecials
    inc     dword [leveltime]

    ; сообщение
    cmp     dword [player + PL_MESSAGETICS], 0
    je      .nomsg
    dec     dword [player + PL_MESSAGETICS]
    jnz     .nomsg
    mov     qword [player + PL_MESSAGE], 0
.nomsg:
    ; возрождение
    cmp     dword [player + PL_STATE], PST_REBORN
    jne     .noreborn
    call    V_StartWipe
    call    G_LoadLevel
    jmp     .done
.noreborn:
    ; переход на следующий уровень -- сперва экран статистики
    cmp     byte [g_exitlevel], 0
    je      .done
    mov     byte [g_exitlevel], 0
    call    WI_Start
.done:
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  D_Display
; ---------------------------------------------------------------------------
D_Display:
    push    rbx
    push    rdi
    cmp     byte [g_gamestate], 2
    jne     .notwi
    call    WI_Drawer
    jmp     .tint
.notwi:
    cmp     byte [g_gamestate], 0
    jne     .level
    call    M_Drawer
    jmp     .tint
.level:
    cmp     byte [am_active], 0
    je      .normalview
    call    AM_Drawer
    jmp     .hud
.normalview:
    call    R_RenderPlayerView
.hud:
    call    ST_Drawer

; --- подкраска палитры: урон, подбор, костюм (как в DOOM) ---
.tint:
    mov     ebx, [player + PL_DAMAGECOUNT]
    ; берсерк подсвечивает экран в начале действия
    mov     eax, [player + PL_POWERS + pw_strength*4]
    test    eax, eax
    jz      .nobzc
    shr     eax, 6
    mov     ecx, 12
    sub     ecx, eax
    cmp     ecx, ebx
    jle     .nobzc
    mov     ebx, ecx
.nobzc:
    test    ebx, ebx
    jz      .nodmg
    add     ebx, 7
    shr     ebx, 3
    cmp     ebx, 8
    jle     .dmgok
    mov     ebx, 8
.dmgok:
    mov     ecx, ebx
    mov     edx, 255
    xor     r8d, r8d
    xor     r9d, r9d
    jmp     .apply
.nodmg:
    mov     ebx, [player + PL_BONUSCOUNT]
    test    ebx, ebx
    jz      .nobonus
    add     ebx, 7
    shr     ebx, 3
    cmp     ebx, 4
    jle     .bonok
    mov     ebx, 4
.bonok:
    mov     ecx, ebx
    mov     edx, 215
    mov     r8d, 186
    mov     r9d, 69
    jmp     .apply
.nobonus:
    mov     eax, [player + PL_POWERS + pw_ironfeet*4]
    test    eax, eax
    jz      .notint
    cmp     eax, 4*32
    jg      .rad
    test    eax, 8
    jz      .notint
.rad:
    mov     ecx, 1
    xor     edx, edx
    mov     r8d, 255
    xor     r9d, r9d
    jmp     .apply
.notint:
    xor     ecx, ecx
    xor     edx, edx
    xor     r8d, r8d
    xor     r9d, r9d
.apply:
    ; пересчитываем таблицу цветов только при смене оттенка
    mov     eax, ecx
    shl     eax, 8
    add     eax, edx
    cmp     [g_curtint], eax
    je      .done
    mov     [g_curtint], eax
    call    V_SetTint
.done:
    call    V_WipeFrame
    pop     rdi
    pop     rbx
    ret
