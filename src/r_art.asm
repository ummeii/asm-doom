; ===========================================================================
;  r_art.asm -- рисованные спрайты: посимвольные картинки из исходника
;
;  Формат арта:
;     db  ширина, высота
;     db  c1..c8          -- восемь индексов палитры
;     db  'строки...'     -- высота строк по ширине символов
;  Символы: '.' -- прозрачно, '1'..'8' -- цвет из палитры арта.
;
;  Таблица artlist привязывает арт к спрайту/кадру/ракурсам и заменяет то,
;  что нарисовал процедурный генератор.
; ===========================================================================

%define ART_W       0
%define ART_H       1
%define ART_PAL     2
%define ART_PIX     10

; запись artlist
%define AL_ART      0       ; dq
%define AL_SPR      8
%define AL_FRAMEMASK 12
%define AL_ROTMASK  16
%define AL_FLIP     20
%define AL_KIND     24      ; 0 = существо/предмет, 1 = оружие в руках
%define AL_PAD      28
%define AL_PALOVR   32      ; dq: своя палитра вместо палитры арта (0 = своя)
%define AL_SIZE     40

; ---------------------------------------------------------------------------
;  R_ArtBlit(rsi = арт, ecx = x назначения, edx = y назначения, r8d = отражение)
;  Рисует поверх текущего bakebuf, прозрачные символы пропускает.
; ---------------------------------------------------------------------------
R_ArtBlit:
    push    rbx
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12d, ecx                   ; dstx
    mov     r13d, edx                   ; dsty
    mov     r14d, r8d                   ; flip
    movzx   r15d, byte [rsi + ART_W]
    movzx   ebx, byte [rsi + ART_H]
    mov     [art_h], ebx
    lea     rdi, [rsi + ART_PIX]        ; пиксели
    xor     ebx, ebx                    ; y
.yl:
    cmp     ebx, [art_h]
    jae     .done
    xor     r8d, r8d                    ; x
.xl:
    cmp     r8d, r15d
    jae     .ynext
    mov     eax, ebx
    imul    eax, r15d
    add     eax, r8d
    movzx   eax, byte [rdi + rax]
    cmp     al, '.'
    je      .next
    cmp     al, ' '
    je      .next
    sub     eax, '1'
    cmp     eax, 8
    jae     .next
    push    rsi
    mov     rsi, [art_palovr]
    test    rsi, rsi
    jnz     .havepal
    pop     rsi
    push    rsi
    lea     rsi, [rsi + ART_PAL]
.havepal:
    movzx   eax, byte [rsi + rax]
    pop     rsi
    ; координата с учётом отражения
    mov     ecx, r8d
    test    r14d, r14d
    jz      .noflip
    mov     ecx, r15d
    dec     ecx
    sub     ecx, r8d
.noflip:
    add     ecx, r12d
    mov     edx, ebx
    add     edx, r13d
    push    r8
    push    rax
    mov     r8d, eax
    call    SPR_Pixel
    pop     rax
    pop     r8
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
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_ApplyArt -- заменяет процедурные спрайты рисованными
; ---------------------------------------------------------------------------
R_ApplyArt:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    lea     r12, [artlist]
.entry:
    mov     rsi, [r12 + AL_ART]
    test    rsi, rsi
    jz      .done
    movzx   r13d, byte [rsi + ART_W]
    movzx   r14d, byte [rsi + ART_H]
    mov     rax, [r12 + AL_PALOVR]
    mov     [art_palovr], rax

    cmp     dword [r12 + AL_KIND], 1
    je      .weapon
    cmp     dword [r12 + AL_KIND], 2
    je      .flash

    ; --- существо/предмет: холст по размеру арта ---
    mov     ecx, r13d
    mov     edx, r14d
    call    SPR_Begin
    xor     ecx, ecx
    xor     edx, edx
    mov     r8d, [r12 + AL_FLIP]
    call    R_ArtBlit
    mov     ecx, r13d
    shr     ecx, 1                      ; leftoffset = половина ширины
    mov     edx, r14d                   ; topoffset = высота (ноги внизу)
    call    SPR_Bake
    jmp     .store

    ; --- вспышка: тот же холст, но арт вверху, у дульного среза ---
.flash:
    mov     ecx, 100
    mov     edx, 128
    call    SPR_Begin
    mov     ecx, 50
    mov     eax, r13d
    shr     eax, 1
    sub     ecx, eax
    mov     edx, 50                     ; на уровне дульного среза
    mov     eax, r14d
    shr     eax, 1
    sub     edx, eax
    mov     r8d, [r12 + AL_FLIP]
    call    R_ArtBlit
    mov     ecx, -110
    mov     edx, -30
    call    SPR_Bake
    jmp     .store

    ; --- оружие: холст 100x128, арт по центру снизу ---
.weapon:
    mov     ecx, 100
    mov     edx, 128
    call    SPR_Begin
    mov     ecx, 50
    mov     eax, r13d
    shr     eax, 1
    sub     ecx, eax
    mov     edx, 128
    sub     edx, r14d
    mov     r8d, [r12 + AL_FLIP]
    call    R_ArtBlit
    mov     ecx, -110
    mov     edx, -30                    ; опустить ствол к нижней кромке вида
    call    SPR_Bake
.store:
    mov     r15, rax                    ; готовый патч
    ; разложить по указанным кадрам и ракурсам
    xor     edi, edi                    ; кадр
.frame:
    mov     eax, [r12 + AL_FRAMEMASK]
    bt      eax, edi
    jnc     .framenext
    xor     ebx, ebx
.rot:
    mov     eax, [r12 + AL_ROTMASK]
    bt      eax, ebx
    jnc     .rotnext
    mov     ecx, [r12 + AL_SPR]
    mov     edx, edi
    mov     r8d, ebx
    mov     r9, r15
    call    R_SetSprite
.rotnext:
    inc     ebx
    cmp     ebx, 8
    jb      .rot
.framenext:
    inc     edi
    cmp     edi, 16
    jb      .frame
    add     r12, AL_SIZE
    jmp     .entry
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
