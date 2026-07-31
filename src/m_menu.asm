; ===========================================================================
;  m_menu.asm -- стартовое меню с выбором сложности
; ===========================================================================

%define NUMSKILLS 5

; ---------------------------------------------------------------------------
;  M_Ticker
; ---------------------------------------------------------------------------
M_Ticker:
    push    rbx
    cmp     byte [g_keyhit + K_UP], 0
    jne     .up
    cmp     byte [g_keyhit + K_W1], 0
    je      .noup
.up:
    dec     dword [m_item]
    jns     .noup
    mov     dword [m_item], NUMSKILLS-1
.noup:
    cmp     byte [g_keyhit + K_DOWN], 0
    je      .nodown
    inc     dword [m_item]
    cmp     dword [m_item], NUMSKILLS
    jb      .nodown
    mov     dword [m_item], 0
.nodown:
    ; запуск новой игры
    cmp     byte [g_keyhit + K_ENTER], 0
    jne     .start
    cmp     byte [g_keyhit + K_FIRE], 0
    je      .nostart
.start:
    mov     eax, [m_item]
    mov     [gameskill], eax
    mov     byte [g_curlevel], 0
    call    V_StartWipe
    call    G_LoadLevel
    mov     byte [g_gamestate], 1
    jmp     .done
.nostart:
    ; вернуться в игру
    cmp     byte [g_keyhit + K_ESC], 0
    je      .done
    cmp     qword [playermo], 0
    je      .quit
    mov     byte [g_gamestate], 1
    jmp     .done
.quit:
    mov     byte [g_quit], 1
.done:
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  M_Drawer
; ---------------------------------------------------------------------------
M_Drawer:
    push    rbx
    push    rsi
    push    rdi
    ; фон
    lea     rdi, [screens]
    mov     ecx, SCREENWIDTH*SCREENHEIGHT/4
    mov     eax, PAL_GRAY + 27
    mov     ah, al
    mov     edx, eax
    shl     eax, 16
    mov     ax, dx
.bg:
    mov     [rdi], eax
    add     rdi, 4
    dec     ecx
    jnz     .bg

    ; заголовок
    mov     rcx, str_title1
    mov     edx, 118
    mov     r8d, 30
    mov     r9d, PAL_RED + 2
    call    ST_DrawString
    mov     rcx, str_title2
    mov     edx, 96
    mov     r8d, 42
    mov     r9d, PAL_TAN + 4
    call    ST_DrawString

    ; пункты
    xor     ebx, ebx
.items:
    mov     eax, ebx
    imul    eax, 14
    add     eax, 70
    mov     r8d, eax                    ; y
    mov     r9d, PAL_GRAY + 8
    cmp     ebx, [m_item]
    jne     .nosel
    mov     r9d, PAL_TAN + 1
.nosel:
    lea     rcx, [skillnames]
    mov     rcx, [rcx + rbx*8]
    mov     edx, 70
    push    rbx
    call    ST_DrawString
    pop     rbx
    ; маркер выбранного
    cmp     ebx, [m_item]
    jne     .itemnext
    mov     rcx, str_cursor
    mov     edx, 56
    mov     eax, ebx
    imul    eax, 14
    add     eax, 70
    mov     r8d, eax
    mov     r9d, PAL_RED + 2
    push    rbx
    call    ST_DrawString
    pop     rbx
.itemnext:
    inc     ebx
    cmp     ebx, NUMSKILLS
    jb      .items

    ; подсказка
    mov     rcx, str_help1
    mov     edx, 60
    mov     r8d, 152
    mov     r9d, PAL_GRAY + 12
    call    ST_DrawString
    mov     rcx, str_help2
    mov     edx, 40
    mov     r8d, 164
    mov     r9d, PAL_GRAY + 12
    call    ST_DrawString
    pop     rdi
    pop     rsi
    pop     rbx
    ret
