; ===========================================================================
;  s_music.asm -- музыка
;
;  Отдельных сэмплов нет: два голоса считаются прямо в микшере. Бас и
;  мелодия -- меандр с фазовым накопителем, громкость каждой ноты спадает
;  к концу шага. Рисунок задан таблицами приращений фазы.
; ===========================================================================

%define MUS_VOL      20                 ; тише эффектов, чтобы не забивать
%define MUS_STEPLEN  (SNDRATE/7)        ; длительность шага в отсчётах
%define MUS_BASSLEN  64
%define MUS_LEADLEN  128
%define MUS_PADLEN   64

; ---------------------------------------------------------------------------
;  S_MusicSample -> eax = отсчёт музыки (-128..127), уже с громкостью
;  Вызывается на каждый кадр микшера, поэтому без пролога.
; ---------------------------------------------------------------------------
S_MusicSample:
    push    rbx
    push    rcx
    push    rdx
    push    rsi

    ; --- продвижение шага ---
    inc     dword [mus_cnt]
    cmp     dword [mus_cnt], MUS_STEPLEN
    jb      .nostep
    mov     dword [mus_cnt], 0
    inc     dword [mus_step]
.nostep:
    ; спад громкости к концу шага: 8 -> 1
    mov     eax, [mus_cnt]
    mov     ecx, MUS_STEPLEN/8
    xor     edx, edx
    div     ecx
    mov     ecx, 8
    sub     ecx, eax
    jg      .envok
    mov     ecx, 1
.envok:
    mov     [mus_env], ecx

    xor     ebx, ebx                    ; накопитель отсчёта

    ; --- бас ---
    mov     eax, [mus_step]
    xor     edx, edx
    mov     ecx, MUS_BASSLEN
    div     ecx
    lea     rsi, [mus_bass]
    mov     eax, [rsi + rdx*4]
    test    eax, eax
    jz      .nobass
    add     [mus_ph1], eax
    mov     eax, [mus_ph1]
    test    eax, 0x8000                 ; меандр
    jz      .b0
    mov     ecx, 52
    jmp     .badd
.b0:
    mov     ecx, -52
.badd:
    imul    ecx, [mus_env]
    sar     ecx, 3
    add     ebx, ecx
.nobass:

    ; --- мелодия ---
    mov     eax, [mus_step]
    xor     edx, edx
    mov     ecx, MUS_LEADLEN
    div     ecx
    lea     rsi, [mus_lead]
    mov     eax, [rsi + rdx*4]
    test    eax, eax
    jz      .nolead
    add     [mus_ph2], eax
    mov     eax, [mus_ph2]
    test    eax, 0x8000
    jz      .l0
    mov     ecx, 26
    jmp     .ladd
.l0:
    mov     ecx, -26
.ladd:
    imul    ecx, [mus_env]
    sar     ecx, 3
    add     ebx, ecx
.nolead:

    ; --- подклад: длинные ноты другим периодом, петля не совпадает с прочими ---
    mov     eax, [mus_step]
    xor     edx, edx
    mov     ecx, MUS_PADLEN
    div     ecx
    lea     rsi, [mus_pad]
    mov     eax, [rsi + rdx*4]
    test    eax, eax
    jz      .nopad
    add     [mus_ph3], eax
    mov     eax, [mus_ph3]
    test    eax, 0x8000
    jz      .p0
    mov     ecx, 30
    jmp     .padd
.p0:
    mov     ecx, -30
.padd:
    add     ebx, ecx                    ; подклад держит ровную громкость
.nopad:

    mov     eax, ebx
    imul    eax, MUS_VOL
    sar     eax, 5
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rbx
    ret
