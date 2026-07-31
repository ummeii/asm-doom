; ===========================================================================
;  st_bar.asm -- строка состояния, шрифт, сообщения
; ===========================================================================

; ---------------------------------------------------------------------------
;  ST_DrawChar(ecx = x, edx = y, r8d = символ, r9d = цвет)
;  Шрифт 4x6 из битовых масок.
; ---------------------------------------------------------------------------
ST_DrawChar:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    mov     r12d, ecx
    mov     r13d, edx
    mov     eax, r8d
    ; поддерживаем 0-9, A-Z, пробел
    cmp     eax, ' '
    je      .done
    cmp     eax, '0'
    jb      .done
    cmp     eax, '9'
    ja      .alpha
    sub     eax, '0'
    jmp     .have
.alpha:
    cmp     eax, 'A'
    jb      .done
    cmp     eax, 'Z'
    ja      .lower
    sub     eax, 'A'
    add     eax, 10
    jmp     .have
.lower:
    cmp     eax, 'a'
    jb      .done
    cmp     eax, 'z'
    ja      .done
    sub     eax, 'a'
    add     eax, 10
.have:
    imul    eax, 6
    lea     rsi, [fontdata]
    add     rsi, rax
    xor     edi, edi                    ; строка
.rowl:
    movzx   ebx, byte [rsi + rdi]
    xor     ecx, ecx
.coll:
    mov     eax, ebx
    mov     edx, 3
    sub     edx, ecx
    mov     r10d, 1
    shl     r10d, cl
    test    ebx, r10d
    jz      .nopix
    mov     eax, r13d
    add     eax, edi
    cmp     eax, SCREENHEIGHT
    jae     .nopix
    imul    eax, SCREENWIDTH
    mov     edx, r12d
    add     edx, ecx
    cmp     edx, SCREENWIDTH
    jae     .nopix
    add     eax, edx
    mov     [screens + rax], r9b
.nopix:
    inc     ecx
    cmp     ecx, 4
    jb      .coll
    inc     edi
    cmp     edi, 6
    jb      .rowl
.done:
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ST_DrawString(rcx = строка, edx = x, r8d = y, r9d = цвет)
ST_DrawString:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    mov     rsi, rcx
    mov     r12d, edx
    mov     r13d, r8d
    mov     edi, r9d
.l:
    movzx   eax, byte [rsi]
    test    eax, eax
    jz      .done
    mov     ecx, r12d
    mov     edx, r13d
    mov     r8d, eax
    mov     r9d, edi
    call    ST_DrawChar
    add     r12d, 5
    inc     rsi
    jmp     .l
.done:
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ST_DrawNum(ecx = число, edx = x (правый край), r8d = y, r9d = цвет)
ST_DrawNum:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    mov     eax, ecx
    mov     r12d, edx
    mov     r13d, r8d
    mov     edi, r9d
    mov     rsi, g_numbuf + 20
    mov     byte [rsi], 0
    test    eax, eax
    jns     .pos
    xor     eax, eax
.pos:
    mov     ebx, 10
.digit:
    dec     rsi
    xor     edx, edx
    div     ebx
    add     dl, '0'
    mov     [rsi], dl
    sub     r12d, 5
    test    eax, eax
    jnz     .digit
    mov     rcx, rsi
    mov     edx, r12d
    add     edx, 5
    mov     r8d, r13d
    mov     r9d, edi
    call    ST_DrawString
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  ST_DrawArt(rsi = арт, ecx = x, edx = y) -- вывод картинки прямо на экран
; ---------------------------------------------------------------------------
ST_DrawArt:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12d, ecx
    mov     r13d, edx
    movzx   r14d, byte [rsi + ART_W]
    movzx   r15d, byte [rsi + ART_H]
    lea     rdi, [rsi + ART_PIX]
    xor     ebx, ebx                    ; y
.yl:
    cmp     ebx, r15d
    jae     .done
    xor     r8d, r8d                    ; x
.xl:
    cmp     r8d, r14d
    jae     .ynext
    mov     eax, ebx
    imul    eax, r14d
    add     eax, r8d
    movzx   eax, byte [rdi + rax]
    cmp     al, '.'
    je      .next
    sub     eax, '1'
    cmp     eax, 8
    jae     .next
    movzx   eax, byte [rsi + ART_PAL + rax]
    mov     ecx, r13d
    add     ecx, ebx
    cmp     ecx, SCREENHEIGHT
    jae     .next
    mov     edx, r12d
    add     edx, r8d
    cmp     edx, SCREENWIDTH
    jae     .next
    imul    ecx, SCREENWIDTH
    add     ecx, edx
    mov     [screens + rcx], al
.next:
    inc     r8d
    jmp     .xl
.ynext:
    inc     ebx
    jmp     .yl
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  ST_BigNum(ecx = число, edx = правый край, r8d = y)
;  Крупные красные цифры, выравнивание по правому краю.
; ---------------------------------------------------------------------------
%define BIGW    14
ST_BigNum:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    mov     eax, ecx
    mov     r12d, edx
    mov     r13d, r8d
    test    eax, eax
    jns     .pos
    xor     eax, eax
.pos:
    lea     rdi, [g_numbuf + 20]
    xor     ebx, ebx                    ; сколько цифр
    mov     esi, 10
.digit:
    xor     edx, edx
    div     esi
    dec     rdi
    mov     [rdi], dl
    inc     ebx
    test    eax, eax
    jnz     .digit
    mov     eax, ebx
    imul    eax, BIGW
    sub     r12d, eax                   ; левый край
.draw:
    movzx   eax, byte [rdi]
    lea     rsi, [bignums]
    mov     rsi, [rsi + rax*8]
    mov     ecx, r12d
    mov     edx, r13d
    push    rdi
    push    rbx
    call    ST_DrawArt
    pop     rbx
    pop     rdi
    add     r12d, BIGW
    inc     rdi
    dec     ebx
    jnz     .draw
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  ST_Bevel(ecx=x0, edx=y0, r8d=x1, r9d=y1) -- утопленная рамка поля
; ---------------------------------------------------------------------------
ST_Bevel:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12d, ecx
    mov     r13d, edx
    mov     r14d, r8d
    mov     r15d, r9d
    mov     dword [sp_color], PAL_GRAY+28
    mov     ecx, r12d
    mov     edx, r13d
    mov     r8d, r14d
    mov     r9d, r13d
    call    ST_FillRect
    mov     ecx, r12d
    mov     edx, r13d
    mov     r8d, r12d
    mov     r9d, r15d
    call    ST_FillRect
    mov     dword [sp_color], PAL_GRAY+12
    mov     ecx, r12d
    mov     edx, r15d
    mov     r8d, r14d
    mov     r9d, r15d
    call    ST_FillRect
    mov     ecx, r14d
    mov     edx, r13d
    mov     r8d, r14d
    mov     r9d, r15d
    call    ST_FillRect
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  ST_DrawBack -- панель строки состояния
; ---------------------------------------------------------------------------
%define STY     (SCREENHEIGHT-32)
ST_DrawBack:
    push    rbx
    push    rsi
    push    rdi
    xor     ebx, ebx
.row:
    mov     eax, ebx
    shr     eax, 3
    add     eax, PAL_GRAY+19
    mov     [sp_color], eax
    mov     ecx, 0
    lea     edx, [ebx + STY]
    mov     r8d, SCREENWIDTH-1
    mov     r9d, edx
    call    ST_FillRect
    inc     ebx
    cmp     ebx, 32
    jb      .row
    mov     dword [sp_color], PAL_GRAY+10
    mov     ecx, 0
    mov     edx, STY
    mov     r8d, SCREENWIDTH-1
    mov     r9d, STY
    call    ST_FillRect
    mov     dword [sp_color], PAL_GRAY+28
    mov     ecx, 0
    mov     edx, STY+1
    mov     r8d, SCREENWIDTH-1
    mov     r9d, STY+1
    call    ST_FillRect
    mov     ebx, 6
.rivet:
    mov     dword [sp_color], PAL_GRAY+8
    mov     ecx, ebx
    mov     edx, STY+3
    lea     r8d, [ebx + 1]
    mov     r9d, STY+4
    call    ST_FillRect
    mov     dword [sp_color], PAL_GRAY+26
    lea     ecx, [ebx + 1]
    mov     edx, STY+4
    lea     r8d, [ebx + 2]
    mov     r9d, STY+5
    call    ST_FillRect
    add     ebx, 32
    cmp     ebx, SCREENWIDTH
    jb      .rivet
    mov     ecx, 2
    mov     edx, STY+3
    mov     r8d, 48
    mov     r9d, STY+22
    call    ST_Bevel                    ; патроны
    mov     ecx, 52
    mov     edx, STY+3
    mov     r8d, 106
    mov     r9d, STY+22
    call    ST_Bevel                    ; здоровье
    mov     ecx, 109
    mov     edx, STY+3
    mov     r8d, 139
    mov     r9d, STY+22
    call    ST_Bevel                    ; оружие
    mov     ecx, 141
    mov     edx, STY+1
    mov     r8d, 167
    mov     r9d, STY+31
    call    ST_Bevel                    ; мордочка
    mov     ecx, 170
    mov     edx, STY+3
    mov     r8d, 236
    mov     r9d, STY+22
    call    ST_Bevel                    ; броня
    mov     ecx, 238
    mov     edx, STY+3
    mov     r8d, 252
    mov     r9d, STY+29
    call    ST_Bevel                    ; ключи
    mov     ecx, 256
    mov     edx, STY+2
    mov     r8d, 318
    mov     r9d, STY+30
    call    ST_Bevel                    ; таблица патронов
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  ST_Ticker -- поворот взгляда и счётчик непрерывной стрельбы
; ---------------------------------------------------------------------------
ST_Ticker:
    push    rbx
    dec     dword [st_facecount]
    jg      .noturn
    call    P_Random
    xor     edx, edx
    mov     ecx, 3
    div     ecx
    mov     [st_facedir], edx           ; 0 влево, 1 прямо, 2 вправо
    mov     dword [st_facecount], 17    ; ST_FACETIME
.noturn:
    cmp     dword [player + PL_ATTACKDOWN], 0
    je      .noatk
    inc     dword [st_rampage]
    jmp     .done
.noatk:
    mov     dword [st_rampage], 0
.done:
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  ST_TurnToAttacker -> eax = 0 влево, 2 вправо, 1 если некуда
; ---------------------------------------------------------------------------
ST_TurnToAttacker:
    push    rbx
    push    rdi
    mov     rdi, [player + PL_ATTACKER]
    test    rdi, rdi
    jz      .center
    mov     rbx, [playermo]
    test    rbx, rbx
    jz      .center
    cmp     rdi, rbx
    je      .center
    mov     ecx, [rbx + MO_X]
    mov     edx, [rbx + MO_Y]
    mov     r8d, [rdi + MO_X]
    mov     r9d, [rdi + MO_Y]
    call    R_PointToAngle2
    sub     eax, [rbx + MO_ANGLE]       ; разница углов по кругу
    cmp     eax, 0x80000000             ; ANG180
    jbe     .left
    mov     eax, 2
    jmp     .out
.left:
    xor     eax, eax
    jmp     .out
.center:
    mov     eax, 1
.out:
    pop     rdi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  ST_Face -> rsi -- какую мордочку показывать
; ---------------------------------------------------------------------------
ST_Face:
    push    rbx
    mov     eax, [player + PL_HEALTH]
    cmp     eax, 0
    jg      .alive
    lea     rsi, [art_facedead]
    jmp     .out
.alive:
    ; степень боли: ((100 - health) * 5) / 101
    cmp     eax, 100
    jle     .hok
    mov     eax, 100
.hok:
    mov     ecx, 100
    sub     ecx, eax
    imul    ecx, 5
    mov     eax, ecx
    xor     edx, edx
    mov     ecx, 101
    div     ecx
    cmp     eax, 4
    jbe     .iok
    mov     eax, 4
.iok:
    mov     ebx, eax                    ; степень боли

    ; получил урон -- либо гримаса, либо поворот к обидчику
    cmp     dword [player + PL_DAMAGECOUNT], 0
    je      .norm
    cmp     dword [st_lastdmg], 20      ; ST_MUCHPAIN
    jl      .turn
    lea     rsi, [art_faceouch]
    jmp     .out
.turn:
    call    ST_TurnToAttacker
    jmp     .pick
.norm:
    ; долгая стрельба -- оскал
    cmp     dword [st_rampage], 35
    jl      .god
    lea     rsi, [art_facegrin]
    jmp     .out
.god:
    test    dword [player + PL_CHEATS], CF_GODMODE
    jnz     .isgod
    cmp     dword [player + PL_POWERS + pw_invulnerability*4], 0
    je      .idle
.isgod:
    lea     rsi, [art_facegod]
    jmp     .out
.idle:
    mov     eax, [st_facedir]
.pick:
    imul    ebx, 3
    add     ebx, eax
    lea     rsi, [facelist]
    mov     rsi, [rsi + rbx*8]
.out:
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  ST_Drawer -- строка состояния
; ---------------------------------------------------------------------------
ST_Drawer:
    push    rbx
    push    rsi
    push    rdi
    call    ST_DrawBack

    ; --- патроны текущего оружия ---
    mov     eax, [player + PL_READYWEAPON]
    imul    eax, WI_SIZE
    mov     ecx, [weaponinfo + rax + WI_AMMO]
    cmp     ecx, am_noammo
    je      .noammo
    mov     ecx, [player + PL_AMMO + rcx*4]
    mov     edx, 46
    mov     r8d, STY+5
    call    ST_BigNum
.noammo:
    ; --- здоровье ---
    mov     ecx, [player + PL_HEALTH]
    mov     edx, 90
    mov     r8d, STY+5
    call    ST_BigNum
    lea     rsi, [art_bigpct]
    mov     ecx, 91
    mov     edx, STY+8
    call    ST_DrawArt

    ; --- броня ---
    mov     ecx, [player + PL_ARMORPOINTS]
    mov     edx, 220
    mov     r8d, STY+5
    call    ST_BigNum
    lea     rsi, [art_bigpct]
    mov     ecx, 221
    mov     edx, STY+8
    call    ST_DrawArt

    ; --- ячейки оружия 2..7 ---
    xor     ebx, ebx
.arms:
    mov     eax, ebx
    xor     edx, edx
    mov     ecx, 3
    div     ecx                         ; eax = строка, edx = столбец
    mov     ecx, edx
    imul    ecx, 10
    add     ecx, 113
    imul    eax, 10
    add     eax, STY+6
    mov     edx, eax
    mov     r8d, ebx
    add     r8d, '2'
    mov     r9d, PAL_GRAY+24            ; нет оружия -- тускло
    cmp     dword [player + PL_WEAPONOWNED + rbx*4 + 4], 0
    je      .armdraw
    mov     r9d, PAL_YELLOW+2
.armdraw:
    push    rbx
    call    ST_DrawChar
    pop     rbx
    inc     ebx
    cmp     ebx, 6
    jb      .arms

    ; --- мордочка ---
    call    ST_Face
    mov     ecx, 143
    mov     edx, STY+2
    call    ST_DrawArt

    ; --- ключи ---
    xor     ebx, ebx
.keys:
    cmp     dword [player + PL_CARDS + rbx*4], 0
    je      .keynext
    lea     rsi, [keyarts]
    mov     rsi, [rsi + rbx*8]
    mov     ecx, 241
    mov     eax, ebx
    imul    eax, 8
    lea     edx, [eax + STY+5]
    push    rbx
    call    ST_DrawArt
    pop     rbx
.keynext:
    inc     ebx
    cmp     ebx, 3
    jb      .keys

    ; --- таблица боезапаса ---
    xor     ebx, ebx
.ammot:
    mov     ecx, [player + PL_AMMO + rbx*4]
    mov     eax, ebx
    imul    eax, 7
    add     eax, STY+4
    mov     r8d, eax
    mov     edx, 288
    mov     r9d, PAL_YELLOW+2
    push    rbx
    call    ST_DrawNum
    pop     rbx
    mov     ecx, [player + PL_MAXAMMO + rbx*4]
    mov     eax, ebx
    imul    eax, 7
    add     eax, STY+4
    mov     r8d, eax
    mov     edx, 316
    mov     r9d, PAL_GRAY+6
    push    rbx
    call    ST_DrawNum
    pop     rbx
    inc     ebx
    cmp     ebx, 4
    jb      .ammot

    ; --- сообщение ---
    mov     rcx, [player + PL_MESSAGE]
    test    rcx, rcx
    jz      .nomsg
    mov     edx, 4
    mov     r8d, 4
    mov     r9d, PAL_TAN+2
    call    ST_DrawString
.nomsg:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ST_FillRect(ecx=x0, edx=y0, r8d=x1, r9d=y1) цвет в sp_color
ST_FillRect:
    push    rbx
    push    rsi
    push    rdi
    mov     esi, edx
.yl:
    cmp     esi, r9d
    jg      .done
    mov     edi, ecx
.xl:
    cmp     edi, r8d
    jg      .ynext
    mov     eax, esi
    imul    eax, SCREENWIDTH
    add     eax, edi
    mov     ebx, [sp_color]
    mov     [screens + rax], bl
    inc     edi
    jmp     .xl
.ynext:
    inc     esi
    jmp     .yl
.done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret
