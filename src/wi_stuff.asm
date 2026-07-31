; ===========================================================================
;  wi_stuff.asm -- экран статистики между уровнями
;
;  Как в оригинале: проценты убитых, найденных предметов и секретов
;  накручиваются по очереди, каждый шаг щёлкает, готовая строка звякает.
;  Дальше по «огонь» или «использовать».
; ===========================================================================

%define WI_KILLS    0
%define WI_ITEMS    1
%define WI_SECRET   2
%define WI_TIME     3
%define WI_DONE     4

%define WI_TICKUP   2                   ; шаг накрутки за тик

; ---------------------------------------------------------------------------
;  WI_Start -- вызывается при выходе с уровня
; ---------------------------------------------------------------------------
WI_Start:
    push    rbx
    mov     dword [wi_stage], WI_KILLS
    mov     dword [wi_shown], 0
    mov     dword [wi_pause], 35
    ; цели в процентах
    mov     ecx, [player + PL_KILLCOUNT]
    mov     edx, [totalkills]
    call    WI_Percent
    mov     [wi_pkills], eax
    mov     ecx, [player + PL_ITEMCOUNT]
    mov     edx, [totalitems]
    call    WI_Percent
    mov     [wi_pitems], eax
    mov     ecx, [player + PL_SECRETCOUNT]
    mov     edx, [totalsecret]
    call    WI_Percent
    mov     [wi_psecret], eax
    mov     eax, [leveltime]
    xor     edx, edx
    mov     ecx, 35
    div     ecx
    mov     [wi_ptime], eax             ; в секундах
    mov     byte [g_gamestate], 2
    pop     rbx
    ret

; WI_Percent(ecx = сделано, edx = всего) -> eax = проценты
WI_Percent:
    test    edx, edx
    jnz     .ok
    mov     eax, 100                    ; нечего было делать -- считаем за сто
    ret
.ok:
    mov     eax, ecx
    imul    eax, 100
    xor     ecx, ecx
    xchg    ecx, edx
    xor     edx, edx
    div     ecx
    cmp     eax, 100
    jbe     .cap
    mov     eax, 100
.cap:
    ret

; ---------------------------------------------------------------------------
;  WI_Ticker
; ---------------------------------------------------------------------------
WI_Ticker:
    push    rbx
    ; переход дальше по кнопке
    cmp     dword [wi_stage], WI_DONE
    jne     .count
    mov     al, [g_keyhit + K_FIRE]
    or      al, [g_keyhit + K_USE]
    or      al, [g_autowalk]            ; автопрогон не ждёт
    jz      .done
    mov     byte [g_gamestate], 1
    call    V_StartWipe
    call    G_NextLevel
    jmp     .done
.count:
    cmp     dword [wi_pause], 0
    jle     .tickup
    dec     dword [wi_pause]
    jmp     .done
.tickup:
    mov     ebx, [wi_stage]
    lea     rax, [wi_pkills]
    mov     eax, [rax + rbx*4]          ; цель текущей строки
    cmp     dword [wi_shown], eax
    jge     .next
    add     dword [wi_shown], WI_TICKUP
    mov     ecx, [wi_shown]
    cmp     ecx, eax
    jle     .snd
    mov     [wi_shown], eax
.snd:
    mov     rcx, [playermo]
    mov     edx, sfx_pistol
    call    S_StartSound
    jmp     .done
.next:
    ; строка добита -- запоминаем и переходим к следующей
    mov     ebx, [wi_stage]
    mov     eax, [wi_shown]
    lea     rdx, [wi_final]
    mov     [rdx + rbx*4], eax
    inc     dword [wi_stage]
    mov     dword [wi_shown], 0
    mov     dword [wi_pause], 21
    mov     rcx, [playermo]
    mov     edx, sfx_swtchn
    call    S_StartSound
.done:
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  WI_Drawer
; ---------------------------------------------------------------------------
WI_Drawer:
    push    rbx
    push    rsi
    ; фон
    mov     dword [sp_color], PAL_GRAY+26
    mov     ecx, 0
    mov     edx, 0
    mov     r8d, SCREENWIDTH-1
    mov     r9d, SCREENHEIGHT-1
    call    ST_FillRect

    ; заголовок
    mov     rcx, str_finished
    mov     edx, 92
    mov     r8d, 16
    mov     r9d, PAL_RED+2
    call    ST_DrawString
    movzx   ecx, byte [g_curlevel]
    inc     ecx
    mov     edx, 134                    ; в промежуток между LEVEL и FINISHED
    mov     r8d, 16
    mov     r9d, PAL_YELLOW+2
    call    ST_DrawNum

    ; --- строки статистики ---
    xor     ebx, ebx
.row:
    cmp     ebx, 3
    jae     .time
    ; подпись
    lea     rax, [wi_labels]
    mov     rcx, [rax + rbx*8]
    mov     edx, 48
    mov     eax, ebx
    imul    eax, 26
    add     eax, 48
    mov     r8d, eax
    mov     r9d, PAL_TAN+2
    push    rbx
    call    ST_DrawString
    pop     rbx
    ; значение: добитые строки берём из wi_final, текущую -- из wi_shown
    cmp     ebx, [wi_stage]
    jl      .fin
    jg      .rownext
    mov     ecx, [wi_shown]
    jmp     .draw
.fin:
    lea     rax, [wi_final]
    mov     ecx, [rax + rbx*4]
.draw:
    mov     edx, 232
    mov     eax, ebx
    imul    eax, 26
    add     eax, 44
    mov     r8d, eax
    push    rbx
    call    ST_BigNum
    lea     rsi, [art_bigpct]
    mov     ecx, 233
    mov     eax, ebx
    imul    eax, 26
    add     eax, 47
    mov     edx, eax
    call    ST_DrawArt
    pop     rbx
.rownext:
    inc     ebx
    jmp     .row

.time:
    cmp     dword [wi_stage], WI_TIME
    jl      .done
    mov     rcx, str_time
    mov     edx, 48
    mov     r8d, 132
    mov     r9d, PAL_TAN+2
    call    ST_DrawString
    mov     ecx, [wi_ptime]
    xor     edx, edx
    push    rcx
    mov     eax, ecx
    xor     edx, edx
    mov     ecx, 60
    div     ecx
    mov     ecx, eax                    ; минуты
    mov     edx, 150
    mov     r8d, 128
    call    ST_BigNum
    pop     rcx
    mov     eax, ecx
    xor     edx, edx
    mov     ecx, 60
    div     ecx
    mov     ecx, edx                    ; секунды
    mov     edx, 200
    mov     r8d, 128
    call    ST_BigNum

    cmp     dword [wi_stage], WI_DONE
    jne     .done
    ; подсказка мигает
    mov     eax, [g_gametic]
    and     eax, 16
    jz      .done
    mov     rcx, str_press
    mov     edx, 88
    mov     r8d, 170
    mov     r9d, PAL_YELLOW+2
    call    ST_DrawString
.done:
    pop     rsi
    pop     rbx
    ret
