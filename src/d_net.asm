; ===========================================================================
;  d_net.asm -- несколько игроков и обмен командами по сети
;
;  Игрок в движке живёт в одной структуре `player`, и к её полям обращаются
;  284 раза по абсолютным адресам. Переписывать все обращения на индекс --
;  большой и рискованный разбор, поэтому сделано иначе: структура остаётся
;  единственной и работает как «окно», а полный набор игроков лежит в
;  массиве `players`. Перед тем как считать тик очередного игрока, его
;  состояние вдвигается в окно, после -- выдвигается обратно. Копирование
;  320 байт дважды на игрока за тик стоит около 45 КБ/с и не заметно.
;
;  По сети летят не координаты, а ticcmd за тик -- шестнадцать байт с
;  движением, поворотом и кнопками. Симуляция на обеих машинах
;  детерминированная, поэтому картинки совпадают. Это же устройство было в
;  сетевом коде оригинала.
;
;  Команды копятся в кольце на BACKUPTICS тиков: своя кладётся в ячейку
;  d_maketic, соперника -- в ячейку с номером из пакета. Тик d_gametic
;  считается, только когда команды на него есть у обоих; поэтому обе машины
;  на каждом тике скармливают симуляции одну и ту же пару команд.
; ===========================================================================

; ---------------------------------------------------------------------------
;  D_InitPlayers -- очистка состояний перед загрузкой карты.
;  Число игроков и свой номер задаются один раз при старте (см. I_NetInit).
; ---------------------------------------------------------------------------
D_InitPlayers:
    push    rbx
    push    rdi
    mov     dword [curplayer], 0
    mov     dword [d_maketic], 0
    mov     dword [d_gametic], 0
    mov     dword [net_peertic], -1
    xor     ebx, ebx
.clr:
    imul    eax, ebx, PLAYER_SIZE
    lea     rdi, [players]
    add     rdi, rax
    mov     ecx, PLAYER_SIZE
    xor     eax, eax
.z:
    mov     [rdi], al
    inc     rdi
    dec     ecx
    jnz     .z
    mov     qword [playermos + rbx*8], 0
    inc     ebx
    cmp     ebx, MAXPLAYERS
    jb      .clr
    ; кольцо команд -- в ноль, иначе первые тики отыграют мусор
    lea     rdi, [netcmds]
    mov     ecx, MAXPLAYERS*BACKUPTICS*TICCMD_SIZE
    xor     eax, eax
.zc:
    mov     [rdi], al
    inc     rdi
    dec     ecx
    jnz     .zc
    ; окно тоже чистим -- в нём сейчас никого
    mov     qword [playermo], 0
    mov     dword [curplayer], 0
    pop     rdi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  D_SwitchPlayer(ecx = номер) -- выдвинуть текущего, вдвинуть нужного.
;  Портит только rax и rcx: вызывающие полагаются на сохранность rdx/r8/r9.
; ---------------------------------------------------------------------------
D_SwitchPlayer:
    push    rbx
    push    rsi
    push    rdi
    cmp     ecx, [curplayer]
    je      .done                       ; уже в окне
    mov     ebx, ecx
    ; --- выдвигаем текущего ---
    mov     eax, [curplayer]
    imul    eax, PLAYER_SIZE
    lea     rdi, [players]
    add     rdi, rax
    lea     rsi, [player]
    mov     ecx, PLAYER_SIZE
    rep     movsb
    mov     eax, [curplayer]
    mov     rcx, [playermo]
    mov     [playermos + rax*8], rcx
    ; --- вдвигаем нужного ---
    imul    eax, ebx, PLAYER_SIZE
    lea     rsi, [players]
    add     rsi, rax
    lea     rdi, [player]
    mov     ecx, PLAYER_SIZE
    rep     movsb
    mov     rcx, [playermos + rbx*8]
    mov     [playermo], rcx
    mov     [curplayer], ebx
.done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  D_SwitchToMobj(rcx = объект) -- вдвинуть в окно игрока, которому он
;  принадлежит. Нужно там, где код работает с чужим игроком: урон, подбор
;  предметов, движение тела в списке thinker'ов.
;  Портит rax, rcx, r10, r11; rdx/r8/r9 сохраняются.
; ---------------------------------------------------------------------------
D_SwitchToMobj:
    xor     r10d, r10d
.l:
    cmp     r10d, [numplayers]
    jae     .done
    cmp     [playermos + r10*8], rcx
    je      .found
    inc     r10d
    jmp     .l
.found:
    mov     ecx, r10d
    call    D_SwitchPlayer
.done:
    ret

; ---------------------------------------------------------------------------
;  D_CmdSlot(ecx = игрок, edx = тик) -> rax = адрес ячейки кольца
; ---------------------------------------------------------------------------
D_CmdSlot:
    and     edx, BACKUPMASK
    imul    ecx, BACKUPTICS
    add     ecx, edx
    imul    ecx, TICCMD_SIZE
    lea     rax, [netcmds]
    add     rax, rcx
    ret

; ---------------------------------------------------------------------------
;  D_StoreCmd(ecx = игрок, edx = тик) -- собранная команда в кольцо
; ---------------------------------------------------------------------------
D_StoreCmd:
    call    D_CmdSlot
    mov     ecx, [pl_forwardmove]
    mov     [rax + TC_FORWARD], ecx
    mov     ecx, [pl_sidemove]
    mov     [rax + TC_SIDE], ecx
    mov     ecx, [pl_angleturn]
    mov     [rax + TC_TURN], ecx
    mov     ecx, [pl_buttons]
    mov     [rax + TC_BUTTONS], ecx
    ret

; ---------------------------------------------------------------------------
;  D_LoadCmd(ecx = игрок, edx = тик) -- команда из кольца в рабочие поля
; ---------------------------------------------------------------------------
D_LoadCmd:
    call    D_CmdSlot
    mov     ecx, [rax + TC_FORWARD]
    mov     [pl_forwardmove], ecx
    mov     ecx, [rax + TC_SIDE]
    mov     [pl_sidemove], ecx
    mov     ecx, [rax + TC_TURN]
    mov     [pl_angleturn], ecx
    mov     ecx, [rax + TC_BUTTONS]
    mov     [pl_buttons], ecx
    ret

; ---------------------------------------------------------------------------
;  D_MakeTic -- снять команду с клавиш, положить в кольцо и отправить.
;  Возвращает eax = 0, если вперёд уходить уже нельзя: тогда клавиши не
;  читаются вовсе и нажатия не теряются.
; ---------------------------------------------------------------------------
D_MakeTic:
    push    rbx
    mov     eax, [d_maketic]
    sub     eax, [d_gametic]
    cmp     eax, NET_MAXLEAD
    jge     .full
    call    G_BuildTiccmd
    mov     ecx, [consoleplayer]
    mov     edx, [d_maketic]
    call    D_StoreCmd
    call    I_NetSend                   ; свою команду -- сопернику
    inc     dword [d_maketic]
    mov     eax, 1
    jmp     .out
.full:
    xor     eax, eax
.out:
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  D_TicReady -> eax = 1, если команды на d_gametic есть у всех
; ---------------------------------------------------------------------------
D_TicReady:
    mov     eax, [d_maketic]
    cmp     eax, [d_gametic]
    jle     .no                         ; своей команды ещё нет
    cmp     dword [net_active], 0
    je      .yes                        ; один игрок -- ждать некого
    mov     eax, [net_peertic]
    cmp     eax, [d_gametic]
    jl      .no
.yes:
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

; ---------------------------------------------------------------------------
;  D_RunPlayers -- тик всех игроков: вдвинуть, подставить команду, считать
; ---------------------------------------------------------------------------
D_RunPlayers:
    push    rbx
    xor     ebx, ebx
.l:
    cmp     ebx, [numplayers]
    jae     .done
    cmp     qword [playermos + rbx*8], 0
    je      .next
    mov     ecx, ebx
    call    D_SwitchPlayer
    mov     ecx, ebx
    mov     edx, [d_gametic]
    call    D_LoadCmd
    call    P_PlayerThink
    ; в сетевой игре павший поднимается на месте старта, карта не грузится
    cmp     dword [net_active], 0
    je      .next
    cmp     dword [player + PL_STATE], PST_REBORN
    jne     .next
    call    D_RespawnPlayer
.next:
    inc     ebx
    jmp     .l
.done:
    ; окно возвращаем своему игроку -- по нему рисуется вид
    mov     ecx, [consoleplayer]
    call    D_SwitchPlayer
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  D_SpawnAt(ecx = номер точки старта) -- поставить тело игрока из окна
; ---------------------------------------------------------------------------
D_SpawnAt:
    push    rbx
    push    rsi
    cmp     dword [numstarts], 0
    je      .done
    mov     eax, ecx
    xor     edx, edx
    div     dword [numstarts]           ; точек может быть меньше, чем игроков
    imul    esi, edx, 12
    mov     ecx, [pstarts + rsi + 0]
    shl     ecx, 16
    mov     edx, [pstarts + rsi + 4]
    shl     edx, 16
    mov     r8d, ONFLOORZ
    mov     r9d, MT_PLAYER
    call    P_SpawnMobj
    test    rax, rax
    jz      .done
    mov     [playermo], rax
    mov     [player + PL_MO], rax
    mov     rbx, rax
    mov     ecx, [pstarts + rsi + 8]
    imul    ecx, ANG1
    mov     [rbx + MO_ANGLE], ecx
    mov     qword [rbx + MO_PLAYER], player
    mov     ecx, [rbx + MO_Z]
    add     ecx, VIEWHEIGHT
    mov     [player + PL_VIEWZ], ecx
    mov     eax, [curplayer]
    mov     [playermos + rax*8], rbx
.done:
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  D_SpawnPlayers -- по телу на каждого игрока после разбора карты
; ---------------------------------------------------------------------------
D_SpawnPlayers:
    push    rbx
    xor     ebx, ebx
.l:
    cmp     ebx, [numplayers]
    jae     .done
    mov     ecx, ebx
    call    D_SwitchPlayer
    mov     ecx, ebx
    call    D_SpawnAt
    call    G_PlayerReborn
    inc     ebx
    jmp     .l
.done:
    mov     ecx, [consoleplayer]
    call    D_SwitchPlayer
    xor     eax, eax
.fz:
    mov     dword [frags + rax*4], 0
    inc     eax
    cmp     eax, MAXPLAYERS
    jb      .fz
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  D_RespawnPlayer -- поднять игрока из окна на точке старта.
;  Труп остаётся лежать, как в бою оригинала, но игроком уже не считается.
; ---------------------------------------------------------------------------
D_RespawnPlayer:
    push    rbx
    mov     rax, [playermo]
    test    rax, rax
    jz      .spawn
    mov     qword [rax + MO_PLAYER], 0
    mov     qword [playermo], 0
    mov     ecx, [curplayer]
    mov     qword [playermos + rcx*8], 0
.spawn:
    mov     ecx, [curplayer]
    call    D_SpawnAt
    call    G_PlayerReborn
    pop     rbx
    ret
