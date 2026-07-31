; ===========================================================================
;  r_plane.asm -- визплейны: полы, потолки и небо (алгоритм DOOM)
; ===========================================================================

%define MAXVISPLANES 2048
%define VP_HEIGHT   0
%define VP_PIC      4
%define VP_LIGHT    8
%define VP_MINX     12
%define VP_MAXX     16
%define VP_TOP      24          ; [x] лежит по VP_TOP+1+x  (322 байта)
%define VP_BOTTOM   348         ; [x] лежит по VP_BOTTOM+1+x
%define VISPLANE_SIZE 672

%define LIGHTLEVELS     16
%define LIGHTSEGSHIFT   4
%define MAXLIGHTSCALE   48
%define LIGHTSCALESHIFT 12
%define MAXLIGHTZ       128
%define LIGHTZSHIFT     20
%define DISTMAP         2

%define ANGLETOSKYSHIFT 22

; ---------------------------------------------------------------------------
;  R_ClearPlanes
; ---------------------------------------------------------------------------
R_ClearPlanes:
    push    rbx
    ; сброс отсечения по столбцам
    xor     ebx, ebx
.clip:
    mov     dword [ceilingclip + rbx*4], -1
    mov     eax, [viewheight]
    mov     [floorclip + rbx*4], eax
    inc     ebx
    cmp     ebx, SCREENWIDTH
    jb      .clip

    mov     dword [lastvisplane], 0
    mov     dword [lastopening], 0

    ; cachedheight[] = 0
    xor     ebx, ebx
.cache:
    mov     dword [cachedheight + rbx*4], 0
    inc     ebx
    cmp     ebx, SCREENHEIGHT
    jb      .cache

    ; basexscale / baseyscale
    mov     eax, [viewangle]
    sub     eax, ANG90
    shr     eax, ANGLETOFINESHIFT
    and     eax, FINEMASK
    mov     ecx, [finecosine + rax*4]
    mov     edx, [centerxfrac]
    push    rax
    call    FixedDiv
    mov     [basexscale], eax
    pop     rax
    mov     ecx, [finesine + rax*4]
    mov     edx, [centerxfrac]
    call    FixedDiv
    neg     eax
    mov     [baseyscale], eax
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_FindPlane(ecx=height, edx=picnum, r8d=lightlevel) -> rax = визплейн
; ---------------------------------------------------------------------------
R_FindPlane:
    push    rbx
    push    rsi
    push    rdi
    cmp     edx, [skyflatnum]
    jne     .nosky
    xor     ecx, ecx
    xor     r8d, r8d
.nosky:
    xor     ebx, ebx
.search:
    cmp     ebx, [lastvisplane]
    jae     .new
    mov     eax, ebx
    imul    eax, VISPLANE_SIZE
    lea     rsi, [visplanes]
    add     rsi, rax
    cmp     [rsi + VP_HEIGHT], ecx
    jne     .next
    cmp     [rsi + VP_PIC], edx
    jne     .next
    cmp     [rsi + VP_LIGHT], r8d
    jne     .next
    mov     rax, rsi
    pop     rdi
    pop     rsi
    pop     rbx
    ret
.next:
    inc     ebx
    jmp     .search
.new:
    cmp     ebx, MAXVISPLANES
    jb      .ok
    mov     ebx, MAXVISPLANES-1         ; переполнение: переиспользуем последний
    mov     eax, ebx
    imul    eax, VISPLANE_SIZE
    lea     rsi, [visplanes]
    add     rsi, rax
    jmp     .init
.ok:
    mov     eax, ebx
    imul    eax, VISPLANE_SIZE
    lea     rsi, [visplanes]
    add     rsi, rax
    inc     dword [lastvisplane]
.init:
    mov     [rsi + VP_HEIGHT], ecx
    mov     [rsi + VP_PIC], edx
    mov     [rsi + VP_LIGHT], r8d
    mov     dword [rsi + VP_MINX], SCREENWIDTH
    mov     dword [rsi + VP_MAXX], -1
    ; top[] = 0xff
    mov     rdi, rsi
    add     rdi, VP_TOP
    mov     eax, 0xffffffff
    mov     ecx, 322/2
    push    rdi
.fill:
    mov     [rdi], ax
    add     rdi, 2
    dec     ecx
    jnz     .fill
    pop     rdi
    mov     rax, rsi
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_CheckPlane(rcx=визплейн, edx=start, r8d=stop) -> rax = визплейн
; ---------------------------------------------------------------------------
R_CheckPlane:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    mov     rsi, rcx
    mov     r12d, edx                   ; start
    mov     r13d, r8d                   ; stop

    ; intrl/unionl
    mov     eax, [rsi + VP_MINX]
    cmp     r12d, eax
    jge     .l1
    mov     r9d, eax                    ; intrl = minx
    mov     r10d, r12d                  ; unionl = start
    jmp     .l2
.l1:
    mov     r9d, r12d                   ; intrl = start
    mov     r10d, eax                   ; unionl = minx
.l2:
    mov     eax, [rsi + VP_MAXX]
    cmp     r13d, eax
    jle     .h1
    mov     r11d, eax                   ; intrh = maxx
    mov     ebx, r13d                   ; unionh = stop
    jmp     .h2
.h1:
    mov     r11d, r13d                  ; intrh = stop
    mov     ebx, eax                    ; unionh = maxx
.h2:
    ; проверяем, свободен ли диапазон пересечения
    mov     edi, r9d
.chk:
    cmp     edi, r11d
    jg      .free
    lea     rax, [rsi + VP_TOP + 1]
    movzx   eax, byte [rax + rdi]
    cmp     eax, 0xff
    jne     .occupied
    inc     edi
    jmp     .chk
.free:
    mov     [rsi + VP_MINX], r10d
    mov     [rsi + VP_MAXX], ebx
    mov     rax, rsi
    jmp     .done
.occupied:
    ; новый визплейн с теми же параметрами
    mov     ecx, [rsi + VP_HEIGHT]
    mov     edx, [rsi + VP_PIC]
    mov     r8d, [rsi + VP_LIGHT]
    mov     eax, [lastvisplane]
    cmp     eax, MAXVISPLANES
    jb      .newok
    mov     rax, rsi                    ; переполнение -- отдаём старый
    jmp     .done
.newok:
    imul    eax, VISPLANE_SIZE
    lea     rdi, [visplanes]
    add     rdi, rax
    inc     dword [lastvisplane]
    mov     [rdi + VP_HEIGHT], ecx
    mov     [rdi + VP_PIC], edx
    mov     [rdi + VP_LIGHT], r8d
    mov     [rdi + VP_MINX], r12d
    mov     [rdi + VP_MAXX], r13d
    push    rdi
    add     rdi, VP_TOP
    mov     eax, 0xffff
    mov     ecx, 322/2
.fill2:
    mov     [rdi], ax
    add     rdi, 2
    dec     ecx
    jnz     .fill2
    pop     rax
.done:
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_MapPlane(ecx=y, edx=x1, r8d=x2)
; ---------------------------------------------------------------------------
R_MapPlane:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    mov     r12d, ecx                   ; y
    mov     r13d, edx                   ; x1
    mov     [ds_x1], edx
    mov     [ds_x2], r8d
    mov     [ds_y], ecx

    mov     eax, [planeheight]
    cmp     eax, [cachedheight + r12*4]
    je      .cached
    mov     [cachedheight + r12*4], eax
    mov     ecx, eax
    mov     edx, [yslope + r12*4]
    call    FixedMul
    mov     [cacheddistance + r12*4], eax
    mov     ebx, eax                    ; distance
    mov     ecx, eax
    mov     edx, [basexscale]
    call    FixedMul
    mov     [cachedxstep + r12*4], eax
    mov     [ds_xstep], eax
    mov     ecx, ebx
    mov     edx, [baseyscale]
    call    FixedMul
    mov     [cachedystep + r12*4], eax
    mov     [ds_ystep], eax
    jmp     .havedist
.cached:
    mov     ebx, [cacheddistance + r12*4]
    mov     eax, [cachedxstep + r12*4]
    mov     [ds_xstep], eax
    mov     eax, [cachedystep + r12*4]
    mov     [ds_ystep], eax
.havedist:
    ; length = FixedMul(distance, distscale[x1])
    mov     ecx, ebx
    mov     edx, [distscale + r13*4]
    call    FixedMul
    mov     esi, eax                    ; length
    mov     eax, [viewangle]
    add     eax, [xtoviewangle + r13*4]
    shr     eax, ANGLETOFINESHIFT
    and     eax, FINEMASK
    mov     edi, eax
    mov     ecx, [finecosine + rdi*4]
    mov     edx, esi
    call    FixedMul
    add     eax, [viewx]
    mov     [ds_xfrac], eax
    mov     ecx, [finesine + rdi*4]
    mov     edx, esi
    call    FixedMul
    mov     ecx, [viewy]
    neg     ecx
    sub     ecx, eax
    mov     [ds_yfrac], ecx

    ; освещение
    mov     rax, [fixedcolormap]
    test    rax, rax
    jz      .lightz
    mov     [ds_colormap], rax
    jmp     .draw
.lightz:
    mov     eax, ebx
    sar     eax, LIGHTZSHIFT
    js      .zzero
    cmp     eax, MAXLIGHTZ
    jb      .zok
    mov     eax, MAXLIGHTZ-1
    jmp     .zok
.zzero:
    xor     eax, eax
.zok:
    mov     rdx, [planezlight]
    mov     rax, [rdx + rax*8]
    mov     [ds_colormap], rax
.draw:
    call    R_DrawSpan
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  R_MakeSpans(ecx=x, edx=t1, r8d=b1, r9d=t2, r10d=b2)
; ---------------------------------------------------------------------------
R_MakeSpans:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12d, ecx                   ; x
    mov     r13d, edx                   ; t1
    mov     r14d, r8d                   ; b1
    mov     r15d, r9d                   ; t2
    mov     ebx, r10d                   ; b2
.w1:
    cmp     r13d, r15d
    jge     .w2
    cmp     r13d, r14d
    jg      .w2
    mov     ecx, r13d
    mov     edx, [spanstart + r13*4]
    lea     r8d, [r12d - 1]
    call    R_MapPlane
    inc     r13d
    jmp     .w1
.w2:
    cmp     r14d, ebx
    jle     .w3
    cmp     r14d, r13d
    jl      .w3
    mov     ecx, r14d
    mov     edx, [spanstart + r14*4]
    lea     r8d, [r12d - 1]
    call    R_MapPlane
    dec     r14d
    jmp     .w2
.w3:
    cmp     r15d, r13d
    jge     .w4
    cmp     r15d, ebx
    jg      .w4
    mov     [spanstart + r15*4], r12d
    inc     r15d
    jmp     .w3
.w4:
    cmp     ebx, r14d
    jle     .done
    cmp     ebx, r15d
    jl      .done
    mov     [spanstart + rbx*4], r12d
    dec     ebx
    jmp     .w4
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
;  R_DrawPlanes -- отрисовать все накопленные визплейны
; ---------------------------------------------------------------------------
R_DrawPlanes:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15

    xor     r12d, r12d                  ; индекс визплейна
.ploop:
    cmp     r12d, [lastvisplane]
    jae     .pdone
    mov     eax, r12d
    imul    eax, VISPLANE_SIZE
    lea     rsi, [visplanes]
    add     rsi, rax
    mov     eax, [rsi + VP_MINX]
    cmp     eax, [rsi + VP_MAXX]
    jg      .pnext

    mov     eax, [rsi + VP_PIC]
    cmp     eax, [skyflatnum]
    jne     .notsky

; ---- небо ----
    mov     eax, [pspriteiscale]
    mov     [dc_iscale], eax
    lea     rax, [colormaps]
    mov     [dc_colormap], rax
    mov     eax, [skytexturemid]
    mov     [dc_texturemid], eax
    mov     ecx, [skytexture]
    call    R_TexHeightMask
    mov     [dc_texmask], eax
    mov     r13d, [rsi + VP_MINX]
.skyloop:
    cmp     r13d, [rsi + VP_MAXX]
    jg      .pnext
    lea     rax, [rsi + VP_TOP + 1]
    movzx   ecx, byte [rax + r13]
    lea     rax, [rsi + VP_BOTTOM + 1]
    movzx   edx, byte [rax + r13]
    cmp     ecx, 0xff
    je      .skynext
    cmp     ecx, edx
    jg      .skynext
    mov     [dc_yl], ecx
    mov     [dc_yh], edx
    mov     [dc_x], r13d
    mov     eax, [viewangle]
    add     eax, [xtoviewangle + r13*4]
    shr     eax, ANGLETOSKYSHIFT
    mov     ecx, [skytexture]
    mov     edx, eax
    call    R_GetColumn
    mov     [dc_source], rax
    call    R_DrawColumn
.skynext:
    inc     r13d
    jmp     .skyloop

; ---- обычный флэт ----
.notsky:
    mov     ecx, [rsi + VP_PIC]
    call    R_GetFlat
    mov     [ds_source], rax
    mov     eax, [rsi + VP_HEIGHT]
    sub     eax, [viewz]
    mov     ecx, eax
    sar     ecx, 31
    xor     eax, ecx
    sub     eax, ecx
    mov     [planeheight], eax
    ; освещение
    mov     eax, [rsi + VP_LIGHT]
    sar     eax, LIGHTSEGSHIFT
    add     eax, [extralight]
    js      .l0
    cmp     eax, LIGHTLEVELS
    jl      .lok
    mov     eax, LIGHTLEVELS-1
    jmp     .lok
.l0:
    xor     eax, eax
.lok:
    imul    eax, MAXLIGHTZ*8
    lea     rdx, [zlight]
    add     rdx, rax
    mov     [planezlight], rdx

    ; ограничители по краям
    mov     eax, [rsi + VP_MAXX]
    lea     rdx, [rsi + VP_TOP + 1]
    mov     byte [rdx + rax + 1], 0xff
    mov     eax, [rsi + VP_MINX]
    mov     byte [rdx + rax - 1], 0xff

    mov     r13d, [rsi + VP_MINX]
    mov     r14d, [rsi + VP_MAXX]
    inc     r14d
.spanloop:
    cmp     r13d, r14d
    jg      .pnext
    lea     rax, [rsi + VP_TOP + 1]
    movzx   edx, byte [rax + r13 - 1]   ; t1
    movzx   r9d, byte [rax + r13]       ; t2
    lea     rax, [rsi + VP_BOTTOM + 1]
    movzx   r8d, byte [rax + r13 - 1]   ; b1
    movzx   r10d, byte [rax + r13]      ; b2
    mov     ecx, r13d
    call    R_MakeSpans
    inc     r13d
    jmp     .spanloop

.pnext:
    inc     r12d
    jmp     .ploop
.pdone:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
