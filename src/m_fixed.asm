; ===========================================================================
;  m_fixed.asm -- арифметика 16.16, углы BAM, тригонометрические таблицы
;
;  Всё повторяет оригинальный DOOM: finesine/finecosine (8192 отсчёта на круг),
;  finetangent, tantoangle + R_PointToAngle/R_PointToDist на их основе.
; ===========================================================================

; st0 -> eax с насыщением в диапазон int32
%macro FST_TO_EAX 0
    fstp    qword [g_dtmp]
    movsd   xmm0, [g_dtmp]
    maxsd   xmm0, [f_intmin]
    minsd   xmm0, [f_intmax]
    cvttsd2si eax, xmm0
%endmacro

; ---------------------------------------------------------------------------
;  R_InitTables -- построение таблиц на старте (x87)
; ---------------------------------------------------------------------------
R_InitTables:
    push    rbx

    ; ---- finesine[i] = sin(2*pi*i/8192) * 65536 ----
    xor     ebx, ebx
.sinloop:
    mov     [g_itmp], ebx
    fild    dword [g_itmp]
    fldpi
    fadd    st0, st0                    ; 2*pi
    fmulp   st1, st0                    ; i*2pi
    fld     dword [f_8192]
    fdivp   st1, st0                    ; угол в радианах
    fsin
    fld     dword [f_65536]
    fmulp   st1, st0
    FST_TO_EAX
    mov     [finesine + rbx*4], eax
    inc     ebx
    cmp     ebx, 8192
    jb      .sinloop

    ; хвост 2048 отсчётов -- чтобы finecosine = finesine+2048 работал
    xor     ebx, ebx
.cpyloop:
    mov     eax, [finesine + rbx*4]
    mov     [finesine + 8192*4 + rbx*4], eax
    inc     ebx
    cmp     ebx, 2048
    jb      .cpyloop

    ; ---- finetangent[i] = tan((i-2047.5)*pi/4096) * 65536 ----
    xor     ebx, ebx
.tanloop:
    mov     [g_itmp], ebx
    fild    dword [g_itmp]
    fld     dword [f_2047h]
    fsubp   st1, st0                    ; i - 2047.5
    fldpi
    fld     dword [f_4096]
    fdivp   st1, st0                    ; pi/4096
    fmulp   st1, st0                    ; аргумент
    fptan                               ; st0=1.0, st1=tan
    fstp    st0
    fld     dword [f_65536]
    fmulp   st1, st0
    FST_TO_EAX
    mov     [finetangent + rbx*4], eax
    inc     ebx
    cmp     ebx, 4096
    jb      .tanloop

    ; ---- tantoangle[i] = atan(i/2048) в BAM ----
    xor     ebx, ebx
.atanloop:
    mov     [g_itmp], ebx
    fild    dword [g_itmp]
    fld     dword [f_2048]
    fdivp   st1, st0                    ; i/2048
    fld1
    fpatan                              ; atan(st1/st0)
    fld     dword [f_ang180]
    fmulp   st1, st0
    fldpi
    fdivp   st1, st0                    ; * ANG180/pi
    FST_TO_EAX
    mov     [tantoangle + rbx*4], eax
    inc     ebx
    cmp     ebx, 2049
    jb      .atanloop

    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  FixedMul(ecx=a, edx=b) -> eax     = (a*b)>>16
; ---------------------------------------------------------------------------
FixedMul:
    mov     eax, ecx
    imul    edx
    shrd    eax, edx, 16
    ret

; ---------------------------------------------------------------------------
;  FixedDiv(ecx=a, edx=b) -> eax     с проверкой переполнения как в DOOM
; ---------------------------------------------------------------------------
FixedDiv:
    mov     eax, ecx
    mov     r8d, ecx
    sar     r8d, 31
    xor     eax, r8d
    sub     eax, r8d                    ; abs(a)
    sar     eax, 14
    mov     r9d, edx
    mov     r10d, edx
    sar     r10d, 31
    xor     r9d, r10d
    sub     r9d, r10d                   ; abs(b)
    cmp     eax, r9d
    jb      FixedDiv2
    mov     eax, ecx
    xor     eax, edx
    test    eax, eax
    js      .neg
    mov     eax, MAXINT
    ret
.neg:
    mov     eax, MININT
    ret

; FixedDiv2(ecx=a, edx=b) -> eax  = (a<<16)/b без проверок
FixedDiv2:
    test    edx, edx
    jz      .zero
    mov     r8d, edx
    mov     eax, ecx
    cdq
    shld    edx, eax, 16
    shl     eax, 16
    idiv    r8d
    ret
.zero:
    mov     eax, MAXINT
    ret

; ---------------------------------------------------------------------------
;  P_AproxDistance(ecx=dx, edx=dy) -> eax
; ---------------------------------------------------------------------------
P_AproxDistance:
    mov     eax, ecx
    sar     eax, 31
    xor     ecx, eax
    sub     ecx, eax
    mov     eax, edx
    sar     eax, 31
    xor     edx, eax
    sub     edx, eax
    cmp     ecx, edx
    jbe     .dylarger
    mov     eax, edx
    sar     eax, 1
    lea     eax, [rcx + rax]
    ret
.dylarger:
    mov     eax, ecx
    sar     eax, 1
    lea     eax, [rdx + rax]
    ret

; ---------------------------------------------------------------------------
;  SlopeDiv(ecx=num, edx=den) -> eax   (беззнаковые)
;    den<512 -> SLOPERANGE;  иначе min((num<<3)/(den>>8), SLOPERANGE)
; ---------------------------------------------------------------------------
SlopeDiv:
    cmp     edx, 512
    jb      .max
    mov     eax, ecx
    shl     eax, 3
    shr     edx, 8
    mov     ecx, edx
    xor     edx, edx
    div     ecx
    cmp     eax, SLOPERANGE
    jbe     .ok
.max:
    mov     eax, SLOPERANGE
.ok:
    ret

; ---------------------------------------------------------------------------
;  R_PointToAngle(ecx=x, edx=y) -> eax    угол на точку из точки обзора
; ---------------------------------------------------------------------------
R_PointToAngle:
    sub     ecx, [viewx]
    sub     edx, [viewy]
    ; -> R_PointToAngleV

; ---------------------------------------------------------------------------
;  R_PointToAngleV(ecx=dx, edx=dy) -> eax  угол вектора
; ---------------------------------------------------------------------------
R_PointToAngleV:
    mov     eax, ecx
    or      eax, edx
    jnz     .notzero
    xor     eax, eax
    ret
.notzero:
    test    ecx, ecx
    js      .xneg
;--- x >= 0 ---
    test    edx, edx
    js      .x_yneg
    ; x>=0, y>=0
    cmp     ecx, edx
    jle     .oct1
    ; октант 0: tantoangle[SlopeDiv(y,x)]
    xchg    ecx, edx                    ; ecx=y(num), edx=x(den)
    call    SlopeDiv
    mov     eax, [tantoangle + rax*4]
    ret
.oct1:                                  ; ANG90-1-tantoangle[SlopeDiv(x,y)]
    call    SlopeDiv
    mov     eax, [tantoangle + rax*4]
    neg     eax
    add     eax, ANG90-1
    ret
.x_yneg:                                ; x>=0, y<0
    neg     edx
    cmp     ecx, edx
    jle     .oct7
    ; октант 8: -tantoangle[SlopeDiv(y,x)]
    xchg    ecx, edx
    call    SlopeDiv
    mov     eax, [tantoangle + rax*4]
    neg     eax
    ret
.oct7:                                  ; ANG270+tantoangle[SlopeDiv(x,y)]
    call    SlopeDiv
    mov     eax, [tantoangle + rax*4]
    add     eax, ANG270
    ret
.xneg:
    neg     ecx
    test    edx, edx
    js      .xn_yneg
    ; x<0, y>=0
    cmp     ecx, edx
    jle     .oct2
    ; октант 3: ANG180-1-tantoangle[SlopeDiv(y,x)]
    xchg    ecx, edx
    call    SlopeDiv
    mov     eax, [tantoangle + rax*4]
    neg     eax
    add     eax, ANG180-1
    ret
.oct2:                                  ; ANG90+tantoangle[SlopeDiv(x,y)]
    call    SlopeDiv
    mov     eax, [tantoangle + rax*4]
    add     eax, ANG90
    ret
.xn_yneg:                               ; x<0, y<0
    neg     edx
    cmp     ecx, edx
    jle     .oct5
    ; октант 4: ANG180+tantoangle[SlopeDiv(y,x)]
    xchg    ecx, edx
    call    SlopeDiv
    mov     eax, [tantoangle + rax*4]
    add     eax, ANG180
    ret
.oct5:                                  ; ANG270-1-tantoangle[SlopeDiv(x,y)]
    call    SlopeDiv
    mov     eax, [tantoangle + rax*4]
    neg     eax
    add     eax, ANG270-1
    ret

; ---------------------------------------------------------------------------
;  R_PointToAngle2(ecx=x1, edx=y1, r8d=x2, r9d=y2) -> eax
; ---------------------------------------------------------------------------
R_PointToAngle2:
    sub     r8d, ecx
    sub     r9d, edx
    mov     ecx, r8d
    mov     edx, r9d
    jmp     R_PointToAngleV

; ---------------------------------------------------------------------------
;  R_PointToDist(ecx=x, edx=y) -> eax   расстояние от точки обзора
; ---------------------------------------------------------------------------
R_PointToDist:
    push    rbx
    push    rsi
    sub     ecx, [viewx]
    mov     eax, ecx
    sar     eax, 31
    xor     ecx, eax
    sub     ecx, eax                    ; dx = abs
    sub     edx, [viewy]
    mov     eax, edx
    sar     eax, 31
    xor     edx, eax
    sub     edx, eax                    ; dy = abs
    cmp     edx, ecx
    jbe     .noswap
    xchg    ecx, edx
.noswap:                                ; ecx=dx >= edx=dy
    test    ecx, ecx
    jnz     .ok
    xor     eax, eax
    pop     rsi
    pop     rbx
    ret
.ok:
    mov     ebx, ecx                    ; dx
    mov     esi, edx                    ; dy
    mov     ecx, esi
    mov     edx, ebx
    call    FixedDiv                    ; dy/dx
    shr     eax, DBITS
    cmp     eax, SLOPERANGE
    jbe     .noclamp
    mov     eax, SLOPERANGE
.noclamp:
    mov     eax, [tantoangle + rax*4]
    add     eax, ANG90
    shr     eax, ANGLETOFINESHIFT
    and     eax, FINEMASK
    mov     edx, [finesine + rax*4]
    mov     ecx, ebx
    call    FixedDiv
    pop     rsi
    pop     rbx
    ret
