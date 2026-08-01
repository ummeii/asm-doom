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
; ===========================================================================

%define NET_MAGIC   0x4D4F4F44          ; 'DOOM'

; ---------------------------------------------------------------------------
;  D_InitPlayers -- один игрок, окно указывает на нулевого
; ---------------------------------------------------------------------------
D_InitPlayers:
    push    rbx
    push    rdi
    mov     dword [numplayers], 1
    mov     dword [consoleplayer], 0
    mov     dword [curplayer], 0
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
    pop     rdi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  D_SwitchPlayer(ecx = номер) -- выдвинуть текущего, вдвинуть нужного
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
;  D_StoreCmd(ecx = игрок) -- сохранить собранную команду в общий буфер
; ---------------------------------------------------------------------------
D_StoreCmd:
    imul    ecx, TICCMD_SIZE
    lea     rax, [netcmds]
    add     rax, rcx
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
;  D_LoadCmd(ecx = игрок) -- достать команду игрока в рабочие переменные
; ---------------------------------------------------------------------------
D_LoadCmd:
    imul    ecx, TICCMD_SIZE
    lea     rax, [netcmds]
    add     rax, rcx
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
    call    D_LoadCmd
    call    P_PlayerThink
.next:
    inc     ebx
    jmp     .l
.done:
    ; окно возвращаем своему игроку -- по нему рисуется вид
    mov     ecx, [consoleplayer]
    call    D_SwitchPlayer
    pop     rbx
    ret
