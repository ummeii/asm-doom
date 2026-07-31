; ===========================================================================
;  s_sound.asm -- процедурный синтез звуков и микшер поверх waveOut
;
;  11025 Гц, 16 бит, стерео. Сэмплы генерируются кодом при старте:
;  шумовые всплески (оружие, взрывы), тоны, рычание, свипы.
; ===========================================================================

%define SNDRATE     11025
%define SNDCHANNELS 8
%define SNDBUFFRAMES 512
%define SNDBUFBYTES (SNDBUFFRAMES*4)    ; 16 бит * 2 канала
%define SNDNUMBUF   4
%define WHDR_DONE   1
%define WAVE_MAPPER -1

; WAVEHDR
%define WH_DATA     0
%define WH_LEN      8
%define WH_RECORDED 12
%define WH_USER     16
%define WH_FLAGS    24
%define WH_LOOPS    28
%define WH_NEXT     32
%define WH_RESERVED 40
%define WAVEHDR_SIZE 48

; канал микшера
%define CH_DATA     0       ; dq  указатель на сэмпл
%define CH_LEN      8       ; dd  длина
%define CH_POS      12      ; dd  позиция 16.16
%define CH_VOLL     16      ; dd  0..256
%define CH_VOLR     20      ; dd
%define CH_ID       24      ; dd  номер звука (0 = свободен)
%define CH_PRIO     28
%define CHAN_SIZE   32

; описание сэмпла: тип, частота/8, длительность/64 отсчётов, параметр
%define SND_NOISE   0
%define SND_TONE    1
%define SND_GROWL   2
%define SND_SWEEP   3
%define SND_CLICK   4

; ---------------------------------------------------------------------------
;  S_Init
; ---------------------------------------------------------------------------
S_Init:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    FRAME

    ; --- генерация сэмплов ---
    xor     ebx, ebx
.genloop:
    imul    eax, ebx, 4
    lea     rsi, [sfxdefs]
    add     rsi, rax
    movzx   eax, byte [rsi + 2]         ; длительность/64
    imul    eax, 64
    test    eax, eax
    jnz     .haslen
    ; пустой звук
    mov     qword [sfxdata + rbx*8], 0
    mov     dword [sfxlen + rbx*4], 0
    jmp     .gennext
.haslen:
    mov     r12d, eax                   ; длина в отсчётах
    mov     [sfxlen + rbx*4], r12d
    mov     ecx, r12d
    add     ecx, 16
    call    Z_Malloc
    mov     [sfxdata + rbx*8], rax
    mov     rdi, rax
    movzx   ecx, byte [rsi + 0]         ; тип
    movzx   edx, byte [rsi + 1]         ; частота/8
    movzx   r8d, byte [rsi + 3]         ; параметр
    mov     r9d, r12d
    call    S_MakeSample
.gennext:
    inc     ebx
    cmp     ebx, NUMSFX
    jb      .genloop

    ; --- очистка каналов ---
    xor     ebx, ebx
.chclr:
    imul    eax, ebx, CHAN_SIZE
    mov     dword [sndchans + rax + CH_ID], 0
    inc     ebx
    cmp     ebx, SNDCHANNELS
    jb      .chclr

    ; --- формат ---
    mov     word  [wfx + 0], 1          ; PCM
    mov     word  [wfx + 2], 2          ; каналов
    mov     dword [wfx + 4], SNDRATE
    mov     dword [wfx + 8], SNDRATE*4
    mov     word  [wfx + 12], 4
    mov     word  [wfx + 14], 16
    mov     word  [wfx + 16], 0

    CALLW   imp_waveOutOpen, hwaveout, WAVE_MAPPER, wfx, 0, 0, 0
    test    eax, eax
    jz      .opened
    mov     qword [hwaveout], 0         ; без звука
    jmp     .done
.opened:
    ; --- подготовка буферов ---
    xor     ebx, ebx
.bufloop:
    imul    esi, ebx, WAVEHDR_SIZE
    lea     rsi, [wavehdrs + rsi]
    mov     eax, ebx
    imul    eax, SNDBUFBYTES
    lea     rdi, [sndbuffers]
    add     rdi, rax
    mov     [rsi + WH_DATA], rdi
    mov     dword [rsi + WH_LEN], SNDBUFBYTES
    mov     dword [rsi + WH_FLAGS], 0
    mov     dword [rsi + WH_LOOPS], 0
    mov     qword [rsi + WH_USER], 0
    CALLW   imp_waveOutPrepareHeader, [hwaveout], rsi, WAVEHDR_SIZE
    ; тишина в первый прогон
    mov     ecx, SNDBUFBYTES/8
    mov     rax, 0
.silence:
    mov     [rdi], rax
    add     rdi, 8
    dec     ecx
    jnz     .silence
    imul    esi, ebx, WAVEHDR_SIZE
    lea     rsi, [wavehdrs + rsi]
    CALLW   imp_waveOutWrite, [hwaveout], rsi, WAVEHDR_SIZE
    inc     ebx
    cmp     ebx, SNDNUMBUF
    jb      .bufloop
.done:
    ENDFRAME
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  S_MakeSample(rdi = буфер, ecx = тип, edx = частота/8, r8d = параметр,
;               r9d = длина)
;  Пишет знаковые 8-битные отсчёты.
; ---------------------------------------------------------------------------
S_MakeSample:
    push    rbx
    push    rsi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12d, ecx                   ; тип
    mov     r13d, edx
    imul    r13d, 8                     ; частота
    mov     r14d, r8d                   ; параметр
    mov     r15d, r9d                   ; длина
    xor     ebx, ebx                    ; номер отсчёта
    mov     dword [sndphase], 0
.l:
    ; огибающая: спад от 255 к 0
    mov     eax, r15d
    sub     eax, ebx
    imul    eax, 255
    xor     edx, edx
    div     r15d
    mov     esi, eax                    ; env 0..255
    ; резкая атака у шумовых
    cmp     r12d, SND_NOISE
    jne     .noatk
    imul    esi, esi
    shr     esi, 8
    imul    esi, esi
    shr     esi, 8
.noatk:

    cmp     r12d, SND_NOISE
    je      .noise
    cmp     r12d, SND_TONE
    je      .tone
    cmp     r12d, SND_GROWL
    je      .growl
    cmp     r12d, SND_SWEEP
    je      .sweep
    ; SND_CLICK
    xor     eax, eax
    cmp     ebx, 40
    jge     .store
    call    S_Rand
    and     eax, 127
    sub     eax, 64
    jmp     .store

.noise:
    call    S_Rand
    and     eax, 255
    sub     eax, 128
    ; параметр = «глухость»: сглаживание с предыдущим отсчётом
    test    r14d, r14d
    jz      .store
    add     eax, [sndprev]
    sar     eax, 1
    mov     [sndprev], eax
    jmp     .store

.tone:
    ; квадратная волна
    mov     eax, [sndphase]
    add     eax, r13d
    mov     [sndphase], eax
    mov     ecx, SNDRATE
    xor     edx, edx
    div     ecx
    mov     eax, edx                    ; фаза внутри периода
    shl     eax, 1
    cmp     eax, SNDRATE
    jb      .toneup
    mov     eax, -100
    jmp     .store
.toneup:
    mov     eax, 100
    jmp     .store

.growl:
    ; низкий тон + шум, с вибрато
    mov     eax, ebx
    shr     eax, 6
    and     eax, 7
    add     eax, r13d
    mov     ecx, eax
    mov     eax, [sndphase]
    add     eax, ecx
    mov     [sndphase], eax
    mov     ecx, SNDRATE
    xor     edx, edx
    div     ecx
    mov     eax, edx
    shl     eax, 1
    cmp     eax, SNDRATE
    jb      .gup
    mov     eax, -70
    jmp     .gmix
.gup:
    mov     eax, 70
.gmix:
    mov     ecx, eax
    call    S_Rand
    and     eax, 63
    sub     eax, 32
    add     eax, ecx
    jmp     .store

.sweep:
    ; частота растёт (или падает) по ходу
    mov     eax, ebx
    imul    eax, r14d
    xor     edx, edx
    div     r15d
    add     eax, r13d
    mov     ecx, eax
    mov     eax, [sndphase]
    add     eax, ecx
    mov     [sndphase], eax
    mov     ecx, SNDRATE
    xor     edx, edx
    div     ecx
    mov     eax, edx
    shl     eax, 1
    cmp     eax, SNDRATE
    jb      .sup
    mov     eax, -90
    jmp     .store
.sup:
    mov     eax, 90

.store:
    imul    eax, esi
    sar     eax, 8
    cmp     eax, 127
    jle     .c1
    mov     eax, 127
.c1:
    cmp     eax, -128
    jge     .c2
    mov     eax, -128
.c2:
    mov     [rdi + rbx], al
    inc     ebx
    cmp     ebx, r15d
    jb      .l
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rsi
    pop     rbx
    ret

S_Rand:
    mov     eax, [sndseed]
    imul    eax, 1103515245
    add     eax, 12345
    mov     [sndseed], eax
    shr     eax, 13
    ret

; ---------------------------------------------------------------------------
;  S_StartSound(rcx = источник (может быть 0), edx = номер звука)
; ---------------------------------------------------------------------------
S_StartSound:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    test    edx, edx
    jz      .done
    cmp     edx, NUMSFX
    jae     .done
    cmp     qword [hwaveout], 0
    je      .done
    mov     r12d, edx
    cmp     qword [sfxdata + r12*8], 0
    je      .done
    mov     rbx, rcx                    ; источник

    ; --- громкость и панорама по расстоянию ---
    mov     r13d, 256                   ; громкость
    mov     esi, 128                    ; панорама (128 = центр)
    test    rbx, rbx
    jz      .havevol
    mov     rax, [playermo]
    test    rax, rax
    jz      .havevol
    cmp     rbx, rax
    je      .havevol
    mov     ecx, [rbx + MO_X]
    sub     ecx, [rax + MO_X]
    mov     edx, [rbx + MO_Y]
    sub     edx, [rax + MO_Y]
    call    P_AproxDistance
    sar     eax, FRACBITS               ; расстояние в единицах
    cmp     eax, 1200
    jl      .near
    xor     r13d, r13d                  ; слишком далеко
    jmp     .done
.near:
    mov     ecx, 1200
    sub     ecx, eax
    imul    ecx, 256
    mov     eax, ecx
    xor     edx, edx
    mov     ecx, 1200
    div     ecx
    mov     r13d, eax
    ; панорама: угол на источник относительно взгляда
    mov     rax, [playermo]
    mov     ecx, [rax + MO_X]
    mov     edx, [rax + MO_Y]
    mov     r8d, [rbx + MO_X]
    mov     r9d, [rbx + MO_Y]
    call    R_PointToAngle2
    mov     rdx, [playermo]
    sub     eax, [rdx + MO_ANGLE]
    shr     eax, ANGLETOFINESHIFT
    and     eax, FINEMASK
    mov     eax, [finesine + rax*4]
    sar     eax, 10                     ; -64..64
    mov     esi, 128
    sub     esi, eax
.havevol:
    test    r13d, r13d
    jz      .done

    ; --- поиск канала ---
    xor     edi, edi
    mov     ecx, -1
.findch:
    imul    eax, edi, CHAN_SIZE
    cmp     dword [sndchans + rax + CH_ID], 0
    jne     .chnext
    mov     ecx, edi
    jmp     .chfound
.chnext:
    inc     edi
    cmp     edi, SNDCHANNELS
    jb      .findch
    xor     ecx, ecx                    ; все заняты -- вытесняем нулевой
.chfound:
    imul    eax, ecx, CHAN_SIZE
    lea     rdi, [sndchans]
    add     rdi, rax
    mov     rax, [sfxdata + r12*8]
    mov     [rdi + CH_DATA], rax
    mov     eax, [sfxlen + r12*4]
    mov     [rdi + CH_LEN], eax
    mov     dword [rdi + CH_POS], 0
    mov     [rdi + CH_ID], r12d
    ; громкость по каналам
    mov     eax, r13d
    imul    eax, esi
    shr     eax, 8
    mov     [rdi + CH_VOLR], eax
    mov     eax, 256
    sub     eax, esi
    imul    eax, r13d
    shr     eax, 8
    mov     [rdi + CH_VOLL], eax
.done:
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  S_UpdateSounds -- дозаполнение буферов waveOut (вызывается каждый кадр)
; ---------------------------------------------------------------------------
S_UpdateSounds:
    push    rbx
    push    rsi
    FRAME
    cmp     qword [hwaveout], 0
    je      .done
    xor     ebx, ebx
.l:
    imul    esi, ebx, WAVEHDR_SIZE
    lea     rsi, [wavehdrs + rsi]
    test    dword [rsi + WH_FLAGS], WHDR_DONE
    jz      .next
    mov     rcx, [rsi + WH_DATA]
    call    S_MixBuffer
    and     dword [rsi + WH_FLAGS], ~WHDR_DONE
    CALLW   imp_waveOutWrite, [hwaveout], rsi, WAVEHDR_SIZE
.next:
    inc     ebx
    cmp     ebx, SNDNUMBUF
    jb      .l
.done:
    ENDFRAME
    pop     rsi
    pop     rbx
    ret

; S_MixBuffer(rcx = выходной буфер) -- SNDBUFFRAMES кадров 16 бит стерео
S_MixBuffer:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rdi, rcx
    xor     r12d, r12d                  ; номер кадра
.frame:
    call    S_MusicSample               ; музыка идёт фоном под эффектами
    imul    eax, 256
    mov     r13d, eax                   ; левый
    mov     r14d, eax                   ; правый
    xor     ebx, ebx
.chan:
    imul    eax, ebx, CHAN_SIZE
    lea     rsi, [sndchans]
    add     rsi, rax
    cmp     dword [rsi + CH_ID], 0
    je      .chnext
    mov     eax, [rsi + CH_POS]
    sar     eax, FRACBITS
    cmp     eax, [rsi + CH_LEN]
    jb      .playing
    mov     dword [rsi + CH_ID], 0      ; закончился
    jmp     .chnext
.playing:
    mov     r15, [rsi + CH_DATA]
    movsx   r15d, byte [r15 + rax]
    mov     eax, r15d
    imul    eax, [rsi + CH_VOLL]
    add     r13d, eax
    mov     eax, r15d
    imul    eax, [rsi + CH_VOLR]
    add     r14d, eax
    mov     eax, [rsi + CH_POS]
    add     eax, FRACUNIT
    mov     [rsi + CH_POS], eax
.chnext:
    inc     ebx
    cmp     ebx, SNDCHANNELS
    jb      .chan
    ; ограничение и запись (сдвиг на 16 бит: -128..127 * 256 -> +-32767)
    mov     eax, r13d
    call    S_Clamp
    mov     [rdi], ax
    mov     eax, r14d
    call    S_Clamp
    mov     [rdi + 2], ax
    add     rdi, 4
    inc     r12d
    cmp     r12d, SNDBUFFRAMES
    jb      .frame
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

S_Clamp:
    cmp     eax, 32767
    jle     .c1
    mov     eax, 32767
.c1:
    cmp     eax, -32768
    jge     .c2
    mov     eax, -32768
.c2:
    ret

; ---------------------------------------------------------------------------
;  S_Shutdown
; ---------------------------------------------------------------------------
S_Shutdown:
    FRAME
    cmp     qword [hwaveout], 0
    je      .done
    CALLW   imp_waveOutReset, [hwaveout]
    CALLW   imp_waveOutClose, [hwaveout]
    mov     qword [hwaveout], 0
.done:
    ENDFRAME
    ret
