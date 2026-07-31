; ===========================================================================
;  i_main.asm -- точка входа, главный цикл, тайминг, ввод, лог
; ===========================================================================

; ---------------------------------------------------------------------------
;  entry
; ---------------------------------------------------------------------------
entry:
    and     rsp, -16
    call    I_ParseCmdLine
    call    L_Open
    call    I_InitGraphics
    call    D_DoomMain
    call    L_Flush
    FRAME
    CALLW   imp_ExitProcess, 0
    hlt

; ---------------------------------------------------------------------------
;  I_ParseCmdLine -- ищем "-shot N": сделать снимок кадра N и выйти
; ---------------------------------------------------------------------------
I_ParseCmdLine:
    push    rsi
    FRAME
    CALLW   imp_GetCommandLineA
    mov     rsi, rax
.scan:
    mov     al, [rsi]
    test    al, al
    je      .done
    cmp     al, '-'
    jne     .next
    mov     eax, [rsi]
    cmp     eax, '-wal'
    jne     .chkshot
    cmp     byte [rsi+4], 'k'
    jne     .chkshot
    mov     byte [g_autowalk], 1        ; автоходьба вперёд (для проверки)
    add     rsi, 5
    jmp     .scan
.chkshot:
    mov     eax, [rsi]
    cmp     eax, '-fir'
    jne     .chkshot2
    cmp     byte [rsi+4], 'e'
    jne     .chkshot2
    mov     byte [g_autofire], 1        ; непрерывная стрельба (для проверки)
    add     rsi, 5
    jmp     .scan
.chkshot2:
    mov     eax, [rsi]
    cmp     eax, '-map'
    jne     .chkshot3
    cmp     byte [rsi+4], ' '
    je      .mapok
    cmp     byte [rsi+4], 0
    jne     .chkshot3
.mapok:
    mov     byte [g_automap0], 1        ; сразу открыть автокарту (для проверки)
    add     rsi, 4
    jmp     .scan
.chkshot3:
    mov     eax, [rsi]
    cmp     eax, '-lev'
    jne     .chkshot4
    add     rsi, 4
    call    I_ParseNum
    test    eax, eax
    jz      .scan
    dec     eax                         ; -lev 2 -> индекс 1
    cmp     eax, NUMLEVELS
    jae     .scan
    mov     [g_startlevel], al          ; с какого уровня начинать (для проверки)
    jmp     .scan
.chkshot4:
    mov     eax, [rsi]
    cmp     eax, '-god'
    jne     .chkshot5
    cmp     byte [rsi+4], ' '
    je      .godok
    cmp     byte [rsi+4], 0
    jne     .chkshot5
.godok:
    mov     byte [g_godmode], 1         ; неуязвимость (для проверки)
    add     rsi, 4
    jmp     .scan
.chkshot5:
    mov     eax, [rsi]
    cmp     eax, '-ski'
    jne     .chkshot6
    cmp     byte [rsi+4], 'l'
    jne     .chkshot6
    add     rsi, 6
    call    I_ParseNum
    dec     eax                         ; -skill 1..5 -> 0..4
    cmp     eax, 5
    jae     .scan
    mov     [g_startskill], al
    mov     byte [g_haveskill], 1
    jmp     .scan
.chkshot6:
    mov     eax, [rsi]
    cmp     eax, '-wip'
    jne     .chkshot7
    cmp     byte [rsi+4], 'e'
    jne     .chkshot7
    mov     byte [g_wipetest], 1        ; запустить расплавление перед снимком
    add     rsi, 5
    jmp     .scan
.chkshot7:
    mov     eax, [rsi]
    cmp     eax, '-sho'
    jne     .next
    cmp     byte [rsi+4], 't'
    jne     .next
    mov     byte [g_shotmode], 1
    add     rsi, 5
    call    I_ParseNum
    test    eax, eax
    jz      .scan
    mov     [g_shottic], eax
    jmp     .scan
.next:
    inc     rsi
    jmp     .scan
.done:
    ENDFRAME
    pop     rsi
    ret

; rsi -> строка; пропустить пробелы, прочитать десятичное число. out: eax
I_ParseNum:
    xor     eax, eax
    xor     r8d, r8d
.skip:
    cmp     byte [rsi], ' '
    jne     .digits
    inc     rsi
    jmp     .skip
.digits:
    movzx   ecx, byte [rsi]
    cmp     cl, '0'
    jb      .end
    cmp     cl, '9'
    ja      .end
    sub     ecx, '0'
    imul    eax, eax, 10
    add     eax, ecx
    inc     rsi
    mov     r8d, 1
    jmp     .digits
.end:
    test    r8d, r8d
    jnz     .ok
    xor     eax, eax
.ok:
    ret

; ---------------------------------------------------------------------------
;  D_DoomMain -- инициализация подсистем и главный цикл
; ---------------------------------------------------------------------------
D_DoomMain:
    FRAME

    call    Z_Init                      ; память
    call    R_InitTables                ; тригонометрия
    call    V_InitPalette               ; палитра + карты освещения
    call    R_InitTextures              ; процедурные текстуры
    call    R_InitSprites               ; процедурные спрайты
    call    S_Init                      ; звук
    call    R_InitRender                ; таблицы рендера
    call    G_InitNew                   ; старт игры

    CALLW   imp_QueryPerformanceFrequency, g_qpf
    CALLW   imp_QueryPerformanceCounter, g_lasttime
    mov     qword [g_ticacc], 0

    ; counts per tic
    mov     rax, [g_qpf]
    xor     rdx, rdx
    mov     rcx, 35
    div     rcx
    mov     [g_ticlen], rax

.loop:
    call    I_PumpMessages
    call    S_UpdateSounds
    cmp     byte [g_quit], 0
    jne     .done

    CALLW   imp_QueryPerformanceCounter, g_nowtime
    mov     rax, [g_nowtime]
    mov     rdx, [g_lasttime]
    mov     [g_lasttime], rax
    sub     rax, rdx
    add     [g_ticacc], rax

    mov     dword [g_ticsrun], 0
.tics:
    mov     rax, [g_ticlen]
    cmp     [g_ticacc], rax
    jb      .noticks
    sub     [g_ticacc], rax
    cmp     dword [g_ticsrun], 5        ; не догоняем больше 5 тиков
    jb      .runtic
    mov     qword [g_ticacc], 0
    jmp     .noticks
.runtic:
    inc     dword [g_ticsrun]
    call    I_ReadInput
    call    G_Ticker
    inc     dword [g_gametic]
    jmp     .tics

.noticks:
    cmp     dword [g_ticsrun], 0
    jne     .render
    CALLW   imp_Sleep, 1
    jmp     .loop

.render:
    ; отладка: запустить расплавление за 12 кадров до снимка
    cmp     byte [g_wipetest], 0
    je      .nowipetest
    mov     eax, [g_gametic]
    add     eax, 12
    cmp     eax, [g_shottic]
    jne     .nowipetest
    call    V_StartWipe
.nowipetest:
    call    D_Display
    call    I_FinishUpdate

    cmp     byte [g_shotmode], 0
    je      .loop
    mov     eax, [g_gametic]
    cmp     eax, [g_shottic]
    jb      .loop
    call    I_Screenshot
    mov     byte [g_quit], 1

.done:
    call    S_Shutdown
    ENDFRAME
    ret

; ---------------------------------------------------------------------------
;  I_PumpMessages
; ---------------------------------------------------------------------------
I_PumpMessages:
    FRAME
.pump:
    CALLW   imp_PeekMessageA, g_msg, 0, 0, 0, PM_REMOVE
    test    eax, eax
    jz      .done
    cmp     dword [g_msg+8], WM_QUIT
    jne     .disp
    mov     byte [g_quit], 1
    jmp     .done
.disp:
    CALLW   imp_TranslateMessage, g_msg
    CALLW   imp_DispatchMessageA, g_msg
    jmp     .pump
.done:
    ENDFRAME
    ret

; ---------------------------------------------------------------------------
;  I_ReadInput -- опрос клавиатуры и мыши
; ---------------------------------------------------------------------------
I_ReadInput:
    push    rbx
    FRAME

    xor     ebx, ebx
.keyloop:
    movzx   ecx, byte [vk_table + rbx]
    CALLW   imp_GetAsyncKeyState, rcx
    test    ax, 0x8000
    setnz   al
    movzx   eax, al
    movzx   ecx, byte [g_keydown + rbx]
    mov     edx, eax
    sub     edx, ecx
    cmp     edx, 1
    sete    dl
    movzx   edx, dl
    mov     [g_keyhit + rbx], dl
    mov     [g_keydown + rbx], al
    inc     ebx
    cmp     ebx, NUMKEYS
    jb      .keyloop

    mov     dword [g_mousex], 0
    mov     dword [g_mousey], 0
    cmp     byte [g_mousegrab], 0
    je      .nomouse
    CALLW   imp_GetForegroundWindow
    cmp     rax, [g_hwnd]
    jne     .nomouse
    CALLW   imp_GetCursorPos, g_pt
    mov     eax, [g_winw]
    shr     eax, 1
    mov     [g_pt2], eax
    mov     eax, [g_winh]
    shr     eax, 1
    mov     [g_pt2+4], eax
    CALLW   imp_ClientToScreen, [g_hwnd], g_pt2
    mov     eax, [g_pt]
    sub     eax, [g_pt2]
    mov     [g_mousex], eax
    mov     eax, [g_pt+4]
    sub     eax, [g_pt2+4]
    mov     [g_mousey], eax
    CALLW   imp_SetCursorPos, [g_pt2], [g_pt2+4]
.nomouse:
    ENDFRAME
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  I_Error(rcx = C-строка) -- пишет error.txt и завершает процесс
; ---------------------------------------------------------------------------
I_Error:
    mov     [g_errmsg], rcx
    call    L_Flush
    FRAME
    CALLW   imp_CreateFileA, str_errfile, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
    mov     [g_fh], rax
    cmp     rax, -1
    je      .noerrfile
    mov     rcx, [g_errmsg]
    call    L_Strlen
    CALLW   imp_WriteFile, [g_fh], [g_errmsg], rax, g_written, 0
    CALLW   imp_CloseHandle, [g_fh]
.noerrfile:
    CALLW   imp_ExitProcess, 1
    hlt

; rcx -> строка, out rax = длина
L_Strlen:
    xor     rax, rax
.l: cmp     byte [rcx + rax], 0
    je      .d
    inc     rax
    jmp     .l
.d: ret

; ---------------------------------------------------------------------------
;  Лог в файл doom.log
; ---------------------------------------------------------------------------
L_Open:
    FRAME
    CALLW   imp_CreateFileA, str_logfile, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
    mov     [g_logfh], rax
    ENDFRAME
    ret

L_Flush:
    FRAME
    mov     eax, [g_logpos]
    test    eax, eax
    jz      .done
    mov     rcx, [g_logfh]
    cmp     rcx, -1
    je      .reset
    test    rcx, rcx
    jz      .reset
    CALLW   imp_WriteFile, [g_logfh], g_logbuf, [g_logpos], g_written, 0
.reset:
    mov     dword [g_logpos], 0
.done:
    ENDFRAME
    ret

; rcx -> строка
L_Str:
    push    rbx
    mov     rbx, rcx
.l: mov     cl, [rbx]
    test    cl, cl
    je      .d
    call    L_Ch
    inc     rbx
    jmp     .l
.d: pop     rbx
    ret

L_Ch:                                   ; cl = символ
    mov     eax, [g_logpos]
    cmp     eax, 3900
    jb      .ok
    push    rcx
    call    L_Flush
    pop     rcx
    mov     eax, [g_logpos]
.ok:
    mov     [g_logbuf + rax], cl
    inc     dword [g_logpos]
    ret

L_Nl:
    push    rbx
    mov     cl, 13
    call    L_Ch
    mov     cl, 10
    call    L_Ch
    call    L_Flush
    pop     rbx
    ret

L_Sp:
    push    rbx
    mov     cl, ' '
    call    L_Ch
    pop     rbx
    ret

; ecx = число со знаком
L_Dec:
    push    rbx
    push    rsi
    mov     eax, ecx
    test    eax, eax
    jns     .pos
    neg     eax
    push    rax
    mov     cl, '-'
    call    L_Ch
    pop     rax
.pos:
    mov     rsi, g_numbuf + 20
    mov     byte [rsi], 0
    mov     ebx, 10
.digit:
    dec     rsi
    xor     edx, edx
    div     ebx
    add     dl, '0'
    mov     [rsi], dl
    test    eax, eax
    jnz     .digit
    mov     rcx, rsi
    call    L_Str
    pop     rsi
    pop     rbx
    ret

; ecx = число (8 hex цифр)
L_Hex:
    push    rbx
    push    rsi
    mov     rsi, g_numbuf
    mov     ebx, ecx
    mov     ecx, 8
.h: rol     ebx, 4
    mov     eax, ebx
    and     eax, 15
    cmp     al, 10
    jb      .dig
    add     al, 'a'-10-'0'
.dig:
    add     al, '0'
    mov     [rsi], al
    inc     rsi
    dec     ecx
    jnz     .h
    mov     byte [rsi], 0
    mov     rcx, g_numbuf
    call    L_Str
    pop     rsi
    pop     rbx
    ret
