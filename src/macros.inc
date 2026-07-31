; ===========================================================================
;  macros.inc -- общие макросы, соглашения о вызовах, fixed-point помощники
; ===========================================================================

; База образа ниже 4 ГБ: в -f bin все метки абсолютные, поэтому адресация идёт
; через абсолютный disp32 (SIB-форма), а не RIP-relative.
%define IMAGEBASE 0x400000

; ---------------------------------------------------------------------------
;  CALLW fn, arg1, arg2, ...   -- вызов функции WinAPI по Win64 ABI
;  (rcx, rdx, r8, r9 + теневые 32 байта, остальное на стеке)
; ---------------------------------------------------------------------------
%macro CALLW 1-*
    %assign _argc %0 - 1
    %if _argc <= 4
        %assign _extra 0
    %else
        %assign _extra ((_argc - 4 + 1) & ~1) * 8
    %endif
    %xdefine _fn %1
    %rotate 1
    sub     rsp, 32 + _extra
    %assign _i 1
    %rep _argc
        %if _i == 1
            mov     rcx, %1
        %elif _i == 2
            mov     rdx, %1
        %elif _i == 3
            mov     r8, %1
        %elif _i == 4
            mov     r9, %1
        %else
            mov     rax, %1
            mov     [rsp + 32 + (_i-5)*8], rax
        %endif
        %assign _i _i+1
        %rotate 1
    %endrep
    call    [_fn]
    add     rsp, 32 + _extra
%endmacro

; ---------------------------------------------------------------------------
;  FRAME/ENDFRAME -- кадр с принудительным выравниванием стека на 16.
;  Обязателен в любой функции, которая делает CALLW.
;  Внутри кадра rbp занят.
;  ВАЖНО: сохранение регистров через push делать ДО FRAME, иначе выравнивание
;  съедет и WinAPI упадёт на movaps.
; ---------------------------------------------------------------------------
%macro FRAME 0
    push    rbp
    mov     rbp, rsp
    and     rsp, -16
%endmacro

%macro ENDFRAME 0
    mov     rsp, rbp
    pop     rbp
%endmacro

; ---------------------------------------------------------------------------
;  Внутреннее соглашение о вызовах (не WinAPI):
;    аргументы: rcx, rdx, r8, r9, далее стек
;    возврат:   eax/rax
;    затираются: rax, rcx, rdx, r8..r11
;    сохраняются: rbx, rbp, rsi, rdi, r12..r15
;  Теневые 32 байта НЕ требуются.
; ---------------------------------------------------------------------------

; --- fixed point 16.16 ---
%define FRACBITS    16
%define FRACUNIT    65536

; --- углы BAM ---
%define ANG45       0x20000000
%define ANG90       0x40000000
%define ANG180      0x80000000
%define ANG270      0xC0000000
%define ANG1        (0x40000000/90)

%define ANGLETOFINESHIFT 19
%define FINEANGLES  8192
%define FINEMASK    (FINEANGLES-1)

%define finecosine  (finesine + 2048*4)

%define SLOPERANGE  2048
%define SLOPEBITS   11
%define DBITS       (FRACBITS-SLOPEBITS)

; ---------------------------------------------------------------------------
;  FixedMul: (a*b)>>16 со знаком.  in: eax, ereg   out: eax
; ---------------------------------------------------------------------------
%macro FIXMUL 1                 ; eax = FixedMul(eax, %1)
    imul    %1                  ; edx:eax
    shrd    eax, edx, 16
%endmacro

; FixedDiv: eax = (a<<16)/b
%macro FIXDIV 1
    cdq
    shld    edx, eax, 16
    sal     eax, 16
    idiv    %1
%endmacro

%define MAXINT      0x7fffffff
%define MININT      0x80000000

; отладочный останов
%macro BREAKPOINT 0
    int3
%endmacro

; ---------------------------------------------------------------------------
;  LOGS "текст" -- немедленная запись строки в doom.log (сохраняет регистры)
; ---------------------------------------------------------------------------
%macro LOGS 1
    jmp     %%over
%%s:
    db      %1, 0
%%over:
    push    rax
    push    rcx
    push    rdx
    push    r8
    push    r9
    push    r10
    push    r11
    mov     rcx, %%s
    call    L_Str
    call    L_Nl
    pop     r11
    pop     r10
    pop     r9
    pop     r8
    pop     rdx
    pop     rcx
    pop     rax
%endmacro

; LOGV "имя", reg32 -- строка + десятичное значение
%macro LOGV 2
    jmp     %%over
%%s:
    db      %1, 0
%%over:
    push    rax
    push    rcx
    push    rdx
    push    r8
    push    r9
    push    r10
    push    r11
    push    rbx
    mov     ebx, %2
    mov     rcx, %%s
    call    L_Str
    mov     ecx, ebx
    call    L_Dec
    call    L_Nl
    pop     rbx
    pop     r11
    pop     r10
    pop     r9
    pop     r8
    pop     rdx
    pop     rcx
    pop     rax
%endmacro
