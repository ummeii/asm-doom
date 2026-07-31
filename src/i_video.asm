; ===========================================================================
;  i_video.asm -- окно, DIB-вывод 320x200x8, палитра, снимок экрана
; ===========================================================================

%define SCREENWIDTH  320
%define SCREENHEIGHT 200

; ---------------------------------------------------------------------------
;  I_InitGraphics
; ---------------------------------------------------------------------------
I_InitGraphics:
    push    rbx
    FRAME
    LOGS    "I_InitGraphics"

    CALLW   imp_GetModuleHandleA, 0
    mov     [g_hinst], rax

    CALLW   imp_LoadCursorA, 0, IDC_ARROW
    mov     [g_hcursor], rax

    ; --- WNDCLASSEXA ---
    mov     dword [g_wc + 0], 80                        ; cbSize
    mov     dword [g_wc + 4], CS_OWNDC|CS_HREDRAW|CS_VREDRAW
    mov     rax, WndProc
    mov     [g_wc + 8], rax
    mov     dword [g_wc + 16], 0
    mov     dword [g_wc + 20], 0
    mov     rax, [g_hinst]
    mov     [g_wc + 24], rax
    mov     qword [g_wc + 32], 0                        ; hIcon
    mov     rax, [g_hcursor]
    mov     [g_wc + 40], rax
    mov     qword [g_wc + 48], 0                        ; hbrBackground
    mov     qword [g_wc + 56], 0                        ; menu
    mov     rax, str_class
    mov     [g_wc + 64], rax
    mov     qword [g_wc + 72], 0
    LOGS    "regclass"
    CALLW   imp_RegisterClassExA, g_wc
    LOGV    "regclass ret=", eax

    ; --- масштаб под экран: клиент = 320*s x 240*s ---
    CALLW   imp_GetSystemMetrics, SM_CYSCREEN
    sub     eax, 140
    js      .small
    xor     edx, edx
    mov     ecx, 240
    div     ecx
    test    eax, eax
    jnz     .s1
.small:
    mov     eax, 1
.s1:
    cmp     eax, 5
    jbe     .s2
    mov     eax, 5
.s2:
    mov     [g_scale], eax
    imul    ecx, eax, SCREENWIDTH
    mov     [g_winw], ecx
    imul    ecx, eax, 240
    mov     [g_winh], ecx

    ; --- размер окна с рамкой ---
    mov     dword [g_rect + 0], 0
    mov     dword [g_rect + 4], 0
    mov     eax, [g_winw]
    mov     [g_rect + 8], eax
    mov     eax, [g_winh]
    mov     [g_rect + 12], eax
    CALLW   imp_AdjustWindowRect, g_rect, WS_OVERLAPPEDWINDOW, 0
    mov     eax, [g_rect + 8]
    sub     eax, [g_rect + 0]
    mov     [g_wndw], eax
    mov     eax, [g_rect + 12]
    sub     eax, [g_rect + 4]
    mov     [g_wndh], eax

    CALLW   imp_CreateWindowExA, 0, str_class, str_title, \
            WS_OVERLAPPEDWINDOW|WS_VISIBLE, CW_USEDEFAULT, CW_USEDEFAULT, \
            [g_wndw], [g_wndh], 0, 0, [g_hinst], 0
    mov     [g_hwnd], rax
    LOGV    "hwnd=", eax
    test    rax, rax
    jnz     .okwin
    mov     rcx, str_err_wnd
    call    I_Error
.okwin:
    CALLW   imp_ShowWindow, [g_hwnd], SW_SHOW
    CALLW   imp_SetForegroundWindow, [g_hwnd]
    CALLW   imp_GetDC, [g_hwnd]
    mov     [g_hdc], rax
    CALLW   imp_SetStretchBltMode, [g_hdc], COLORONCOLOR

    ; --- BITMAPINFOHEADER ---
    mov     dword [g_bmi + 0], 40
    mov     dword [g_bmi + 4], SCREENWIDTH
    mov     dword [g_bmi + 8], -SCREENHEIGHT            ; top-down
    mov     word  [g_bmi + 12], 1
    mov     word  [g_bmi + 14], 8
    mov     dword [g_bmi + 16], 0                       ; BI_RGB
    mov     dword [g_bmi + 20], 0
    mov     dword [g_bmi + 24], 0
    mov     dword [g_bmi + 28], 0
    mov     dword [g_bmi + 32], 256
    mov     dword [g_bmi + 36], 256
    LOGS    "I_InitGraphics done"

    ENDFRAME
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  I_SetPalette -- перенос g_palette (RGB) в таблицу цветов DIB (BGRX)
; ---------------------------------------------------------------------------
I_SetPalette:
    push    rbx
    xor     ecx, ecx
.l:
    lea     rbx, [g_palette]
    lea     r8, [rbx + rcx*2]
    add     r8, rcx                     ; g_palette + i*3
    movzx   eax, byte [r8 + 2]          ; B
    mov     [g_bmi + 40 + rcx*4 + 0], al
    movzx   eax, byte [r8 + 1]          ; G
    mov     [g_bmi + 40 + rcx*4 + 1], al
    movzx   eax, byte [r8 + 0]          ; R
    mov     [g_bmi + 40 + rcx*4 + 2], al
    mov     byte [g_bmi + 40 + rcx*4 + 3], 0
    inc     ecx
    cmp     ecx, 256
    jb      .l
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  V_SetTint(ecx = сила 0..9, edx = R, r8d = G, r9d = B)
;    Как в DOOM: экран не перекрашивается попиксельно, подмешивается оттенок
;    в саму палитру -- вспышка урона, подбор предмета, костюм радзащиты.
; ---------------------------------------------------------------------------
V_SetTint:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12d, ecx                   ; сила
    mov     r13d, edx                   ; R
    mov     r14d, r8d                   ; G
    mov     r15d, r9d                   ; B
    xor     ebx, ebx
.l:
    lea     rsi, [g_palette]
    lea     rsi, [rsi + rbx*2]
    add     rsi, rbx                    ; g_palette + i*3
    ; B
    movzx   eax, byte [rsi + 2]
    mov     ecx, r15d
    call    V_Blend
    mov     [g_bmi + 40 + rbx*4 + 0], al
    ; G
    movzx   eax, byte [rsi + 1]
    mov     ecx, r14d
    call    V_Blend
    mov     [g_bmi + 40 + rbx*4 + 1], al
    ; R
    movzx   eax, byte [rsi + 0]
    mov     ecx, r13d
    call    V_Blend
    mov     [g_bmi + 40 + rbx*4 + 2], al
    mov     byte [g_bmi + 40 + rbx*4 + 3], 0
    inc     ebx
    cmp     ebx, 256
    jb      .l
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; V_Blend(eax = исходный канал, ecx = целевой) -> al;  сила в r12d
V_Blend:
    push    rdx
    push    rcx
    sub     ecx, eax                    ; diff со знаком
    imul    ecx, r12d
    push    rax
    mov     eax, ecx
    cdq
    mov     ecx, 9
    idiv    ecx
    mov     ecx, eax
    pop     rax
    add     eax, ecx
    test    eax, eax
    jns     .c1
    xor     eax, eax
.c1:
    cmp     eax, 255
    jle     .c2
    mov     eax, 255
.c2:
    pop     rcx
    pop     rdx
    ret

; ---------------------------------------------------------------------------
;  I_FinishUpdate -- вывод кадра на экран
; ---------------------------------------------------------------------------
I_FinishUpdate:
    FRAME
    CALLW   imp_GetClientRect, [g_hwnd], g_rect
    mov     eax, [g_rect + 8]
    mov     [g_winw], eax
    mov     eax, [g_rect + 12]
    mov     [g_winh], eax
    CALLW   imp_StretchDIBits, [g_hdc], 0, 0, [g_winw], [g_winh], \
            0, 0, SCREENWIDTH, SCREENHEIGHT, screens, g_bmi, \
            DIB_RGB_COLORS, SRCCOPY
    ENDFRAME
    ret

; ---------------------------------------------------------------------------
;  WndProc(rcx=hwnd, rdx=msg, r8=wparam, r9=lparam)
; ---------------------------------------------------------------------------
WndProc:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 64
    and     rsp, -16
    mov     [rbp-8], rcx
    mov     [rbp-16], rdx
    mov     [rbp-24], r8
    mov     [rbp-32], r9

    cmp     edx, WM_CLOSE
    je      .close
    cmp     edx, WM_DESTROY
    je      .close
    cmp     edx, WM_SYSCOMMAND
    je      .syscmd
    cmp     edx, WM_ACTIVATE
    je      .activate
    jmp     .default

.close:
    mov     byte [g_quit], 1
    CALLW   imp_PostQuitMessage, 0
    xor     eax, eax
    jmp     .ret

.syscmd:
    mov     eax, r8d
    and     eax, 0xfff0
    cmp     eax, SC_KEYMENU
    je      .zero
    cmp     eax, SC_SCREENSAVE
    je      .zero
    cmp     eax, SC_MONITORPOWER
    je      .zero
    jmp     .default
.zero:
    xor     eax, eax
    jmp     .ret

.activate:
    mov     eax, [rbp-24]
    test    ax, ax
    jz      .deact
    mov     byte [g_active], 1
    jmp     .default
.deact:
    mov     byte [g_active], 0
    jmp     .default

.default:
    CALLW   imp_DefWindowProcA, [rbp-8], [rbp-16], [rbp-24], [rbp-32]
.ret:
    mov     rsp, rbp
    pop     rbp
    ret

; ---------------------------------------------------------------------------
;  I_Screenshot -- сохранить кадр в shot.bmp (8 бит с палитрой)
; ---------------------------------------------------------------------------
I_Screenshot:
    push    rbx
    push    rsi
    push    rdi
    FRAME

    ; BITMAPFILEHEADER
    mov     word  [g_bmpbuf + 0], 0x4d42               ; 'BM'
    mov     dword [g_bmpbuf + 2], 14 + 40 + 1024 + SCREENWIDTH*SCREENHEIGHT
    mov     dword [g_bmpbuf + 6], 0
    mov     dword [g_bmpbuf + 10], 14 + 40 + 1024
    ; BITMAPINFOHEADER
    mov     dword [g_bmpbuf + 14 + 0], 40
    mov     dword [g_bmpbuf + 14 + 4], SCREENWIDTH
    mov     dword [g_bmpbuf + 14 + 8], SCREENHEIGHT
    mov     word  [g_bmpbuf + 14 + 12], 1
    mov     word  [g_bmpbuf + 14 + 14], 8
    mov     dword [g_bmpbuf + 14 + 16], 0
    mov     dword [g_bmpbuf + 14 + 20], SCREENWIDTH*SCREENHEIGHT
    mov     dword [g_bmpbuf + 14 + 24], 2835
    mov     dword [g_bmpbuf + 14 + 28], 2835
    mov     dword [g_bmpbuf + 14 + 32], 256
    mov     dword [g_bmpbuf + 14 + 36], 256
    ; палитра
    xor     ecx, ecx
.pal:
    lea     r8, [g_palette + rcx*2]
    add     r8, rcx
    movzx   eax, byte [r8 + 2]
    mov     [g_bmpbuf + 54 + rcx*4 + 0], al
    movzx   eax, byte [r8 + 1]
    mov     [g_bmpbuf + 54 + rcx*4 + 1], al
    movzx   eax, byte [r8 + 0]
    mov     [g_bmpbuf + 54 + rcx*4 + 2], al
    mov     byte [g_bmpbuf + 54 + rcx*4 + 3], 0
    inc     ecx
    cmp     ecx, 256
    jb      .pal
    ; пиксели снизу вверх
    lea     rdi, [g_bmpbuf + 1078]
    mov     esi, SCREENHEIGHT - 1
.row:
    mov     eax, esi
    imul    eax, SCREENWIDTH
    lea     rbx, [screens]
    add     rbx, rax
    mov     ecx, SCREENWIDTH
.col:
    mov     al, [rbx]
    mov     [rdi], al
    inc     rbx
    inc     rdi
    dec     ecx
    jnz     .col
    dec     esi
    jns     .row

    CALLW   imp_CreateFileA, str_shotfile, GENERIC_WRITE, 0, 0, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0
    mov     [g_fh], rax
    cmp     rax, -1
    je      .done
    CALLW   imp_WriteFile, [g_fh], g_bmpbuf, 14+40+1024+SCREENWIDTH*SCREENHEIGHT, g_written, 0
    CALLW   imp_CloseHandle, [g_fh]
.done:
    ENDFRAME
    pop     rdi
    pop     rsi
    pop     rbx
    ret
