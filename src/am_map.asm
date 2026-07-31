; ===========================================================================
;  am_map.asm -- автокарта: вид сверху на изученные линии уровня
; ===========================================================================

%define AM_COL_WALL     (PAL_RED + 6)      ; глухая стена
%define AM_COL_FLOOR    (PAL_BROWN + 10)   ; двусторонняя, разный пол
%define AM_COL_CEIL     (PAL_YELLOW + 4)   ; двусторонняя, разный потолок
%define AM_COL_TWO      (PAL_GRAY + 20)    ; прочие двусторонние
%define AM_COL_PLAYER   (PAL_GREEN + 2)
%define AM_COL_BACK     (PAL_GRAY + 28)

; ---------------------------------------------------------------------------
;  AM_Start / AM_Stop
; ---------------------------------------------------------------------------
AM_Start:
    mov     byte [am_active], 1
    mov     dword [am_scale], FRACUNIT/8
    ret

AM_Stop:
    mov     byte [am_active], 0
    ret

; ---------------------------------------------------------------------------
;  AM_Ticker -- масштаб и следование за игроком
; ---------------------------------------------------------------------------
AM_Ticker:
    push    rbx
    cmp     byte [am_active], 0
    je      .done
    cmp     byte [g_keydown + K_PLUS], 0
    je      .noplus
    mov     eax, [am_scale]
    imul    eax, 9
    sar     eax, 3
    cmp     eax, FRACUNIT
    jle     .setplus
    mov     eax, FRACUNIT
.setplus:
    mov     [am_scale], eax
.noplus:
    cmp     byte [g_keydown + K_MINUS], 0
    je      .nominus
    mov     eax, [am_scale]
    imul    eax, 7
    sar     eax, 3
    cmp     eax, FRACUNIT/64
    jge     .setminus
    mov     eax, FRACUNIT/64
.setminus:
    mov     [am_scale], eax
.nominus:
    ; центр -- на игроке
    mov     rax, [playermo]
    test    rax, rax
    jz      .done
    mov     ecx, [rax + MO_X]
    mov     [am_cx], ecx
    mov     ecx, [rax + MO_Y]
    mov     [am_cy], ecx
.done:
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  AM_ToScreen(ecx = мировой x, edx = мировой y) -> eax = sx, edx = sy
; ---------------------------------------------------------------------------
AM_ToScreen:
    push    rbx
    sub     ecx, [am_cx]
    sub     edx, [am_cy]
    mov     ebx, edx
    mov     edx, [am_scale]
    call    FixedMul
    sar     eax, FRACBITS
    add     eax, 160
    push    rax
    mov     ecx, ebx
    mov     edx, [am_scale]
    call    FixedMul
    sar     eax, FRACBITS
    mov     edx, 84
    sub     edx, eax                    ; экранный Y растёт вниз
    pop     rax
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  AM_Line(ecx=x0, edx=y0, r8d=x1, r9d=y1, [am_color]) -- Брезенхэм с обрезкой
; ---------------------------------------------------------------------------
AM_Line:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     esi, ecx                    ; x
    mov     edi, edx                    ; y
    mov     r12d, r8d                   ; x1
    mov     r13d, r9d                   ; y1
    ; dx = |x1-x|, sx
    mov     eax, r12d
    sub     eax, esi
    mov     r14d, 1
    test    eax, eax
    jns     .dxp
    neg     eax
    mov     r14d, -1
.dxp:
    mov     ebx, eax                    ; dx
    ; dy = -|y1-y|, sy
    mov     eax, r13d
    sub     eax, edi
    mov     r15d, 1
    test    eax, eax
    jns     .dyp
    neg     eax
    mov     r15d, -1
.dyp:
    neg     eax
    mov     r8d, eax                    ; dy (отрицательное)
    mov     r9d, ebx
    add     r9d, r8d                    ; err
    xor     r10d, r10d                  ; счётчик шагов
.loop:
    inc     r10d
    cmp     r10d, 1000
    ja      .done
    ; вывод точки
    cmp     esi, 0
    jl      .skip
    cmp     esi, SCREENWIDTH
    jge     .skip
    cmp     edi, 0
    jl      .skip
    cmp     edi, SCREENHEIGHT-32
    jge     .skip
    mov     eax, edi
    imul    eax, SCREENWIDTH
    add     eax, esi
    mov     ecx, [am_color]
    mov     [screens + rax], cl
.skip:
    cmp     esi, r12d
    jne     .step
    cmp     edi, r13d
    je      .done
.step:
    mov     eax, r9d
    add     eax, eax                    ; e2 = 2*err
    cmp     eax, r8d
    jl      .nox
    add     r9d, r8d
    add     esi, r14d
.nox:
    cmp     eax, ebx
    jg      .noy
    add     r9d, ebx
    add     edi, r15d
.noy:
    jmp     .loop
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
;  AM_Drawer
; ---------------------------------------------------------------------------
AM_Drawer:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15

    ; фон
    lea     rdi, [screens]
    mov     ecx, SCREENWIDTH*(SCREENHEIGHT-32)/4
    mov     eax, AM_COL_BACK
    mov     ah, al
    mov     edx, eax
    shl     eax, 16
    mov     ax, dx
.bg:
    mov     [rdi], eax
    add     rdi, 4
    dec     ecx
    jnz     .bg

    ; --- линии ---
    xor     ebx, ebx
.lineloop:
    cmp     ebx, [numlines]
    jae     .linesdone
    imul    r12d, ebx, LINE_SIZE
    ; показываем только изученные (или всё по карте-компьютеру)
    cmp     dword [player + PL_POWERS + pw_allmap*4], 0
    jne     .visible
    test    dword [lines + r12 + LN_FLAGS], ML_MAPPED
    jz      .linenext
.visible:
    test    dword [lines + r12 + LN_FLAGS], ML_DONTDRAW
    jnz     .linenext
    ; цвет по типу линии
    mov     eax, [lines + r12 + LN_BACKSEC]
    cmp     eax, -1
    jne     .twosided
    mov     dword [am_color], AM_COL_WALL
    jmp     .havecolor
.twosided:
    imul    eax, SECTOR_SIZE
    mov     ecx, [lines + r12 + LN_FRONTSEC]
    imul    ecx, SECTOR_SIZE
    mov     edx, [sectors + rax + SEC_FLOORH]
    cmp     edx, [sectors + rcx + SEC_FLOORH]
    jne     .floordiff
    mov     edx, [sectors + rax + SEC_CEILH]
    cmp     edx, [sectors + rcx + SEC_CEILH]
    jne     .ceildiff
    mov     dword [am_color], AM_COL_TWO
    jmp     .havecolor
.floordiff:
    mov     dword [am_color], AM_COL_FLOOR
    jmp     .havecolor
.ceildiff:
    mov     dword [am_color], AM_COL_CEIL
.havecolor:
    ; концы линии
    mov     eax, [lines + r12 + LN_V1]
    imul    eax, VERTEX_SIZE
    mov     ecx, [vertexes + rax + VX_X]
    mov     edx, [vertexes + rax + VX_Y]
    call    AM_ToScreen
    mov     r13d, eax
    mov     r14d, edx
    mov     eax, [lines + r12 + LN_V2]
    imul    eax, VERTEX_SIZE
    mov     ecx, [vertexes + rax + VX_X]
    mov     edx, [vertexes + rax + VX_Y]
    call    AM_ToScreen
    mov     r8d, eax
    mov     r9d, edx
    mov     ecx, r13d
    mov     edx, r14d
    call    AM_Line
.linenext:
    inc     ebx
    jmp     .lineloop
.linesdone:

    ; --- стрелка игрока ---
    mov     rsi, [playermo]
    test    rsi, rsi
    jz      .done
    mov     dword [am_color], AM_COL_PLAYER
    xor     r15d, r15d
.arrow:
    ; сегменты стрелки заданы в локальных координатах
    imul    eax, r15d, 4
    lea     rdi, [am_arrow]
    add     rdi, rax
    movsx   r12d, byte [rdi + 0]
    movsx   r13d, byte [rdi + 1]
    movsx   r14d, byte [rdi + 2]
    movsx   eax, byte [rdi + 3]
    mov     [am_tmp], eax
    ; поворот на угол игрока и перевод в мировые координаты
    mov     ecx, r12d
    mov     edx, r13d
    call    AM_Rotate
    push    rax
    push    rdx
    mov     ecx, r14d
    mov     edx, [am_tmp]
    call    AM_Rotate
    mov     r8d, eax
    mov     r9d, edx
    pop     rdx
    pop     rcx
    call    AM_Line
    inc     r15d
    cmp     r15d, AM_ARROWSEG
    jb      .arrow
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; AM_Rotate(ecx = локальный x, edx = локальный y) -> eax = sx, edx = sy
;  Локальные координаты в «клетках» стрелки, поворот по углу игрока.
AM_Rotate:
    push    rbx
    push    rsi
    push    rdi
    mov     esi, ecx
    mov     edi, edx
    mov     rax, [playermo]
    mov     eax, [rax + MO_ANGLE]
    shr     eax, ANGLETOFINESHIFT
    and     eax, FINEMASK
    mov     ebx, eax
    ; x' = x*cos - y*sin,  y' = x*sin + y*cos  (в экранных пикселях)
    mov     eax, [finecosine + rbx*4]
    sar     eax, 12
    imul    eax, esi
    mov     ecx, [finesine + rbx*4]
    sar     ecx, 12
    imul    ecx, edi
    sub     eax, ecx
    sar     eax, 4
    add     eax, 160
    push    rax
    mov     eax, [finesine + rbx*4]
    sar     eax, 12
    imul    eax, esi
    mov     ecx, [finecosine + rbx*4]
    sar     ecx, 12
    imul    ecx, edi
    add     eax, ecx
    sar     eax, 4
    mov     edx, 84
    sub     edx, eax
    pop     rax
    pop     rdi
    pop     rsi
    pop     rbx
    ret
