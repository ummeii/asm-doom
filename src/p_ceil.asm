; ===========================================================================
;  p_ceil.asm -- движение потолков, давящие потолки, лестницы
;
;  Порт t_MoveCeiling / EV_DoCeiling / EV_BuildStairs из p_ceilng.c и
;  p_floor.c, плюс P_ChangeSector с раздавливанием из p_map.c.
; ===========================================================================

; ---------------------------------------------------------------------------
;  P_InitCeilings -- очистка при загрузке уровня
; ---------------------------------------------------------------------------
P_InitCeilings:
    push    rbx
    xor     ebx, ebx
.l:
    imul    eax, ebx, CEIL_SIZE
    mov     dword [ceilmoves + rax + CL_INUSE], 0
    inc     ebx
    cmp     ebx, MAXCEILINGS
    jb      .l
    mov     dword [nofit], 0
    mov     dword [crushchange], 0
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_FindHighestCeilingSurrounding(ecx = сектор) -> eax
; ---------------------------------------------------------------------------
P_FindHighestCeilingSurrounding:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    imul    r12d, ecx, SECTOR_SIZE
    mov     r13d, ecx
    mov     edi, -32000*FRACUNIT
    xor     ebx, ebx
.l:
    cmp     ebx, [sectors + r12 + SEC_LINECOUNT]
    jae     .done
    mov     rsi, [sectors + r12 + SEC_LINES]
    mov     eax, [rsi + rbx*4]
    imul    eax, LINE_SIZE
    ; сосед по линии
    mov     ecx, [lines + rax + LN_FRONTSEC]
    cmp     ecx, r13d
    jne     .havenb
    mov     ecx, [lines + rax + LN_BACKSEC]
.havenb:
    cmp     ecx, -1
    je      .next
    cmp     ecx, r13d
    je      .next
    imul    ecx, SECTOR_SIZE
    mov     eax, [sectors + rcx + SEC_CEILH]
    cmp     eax, edi
    jle     .next
    mov     edi, eax
.next:
    inc     ebx
    jmp     .l
.done:
    mov     eax, edi
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_ChangeSector(ecx = сектор, edx = давить) -> eax = 1, если что-то мешает
;
;  Как PIT_ChangeSector: пересчитываем опоры всех объектов сектора; кому
;  не хватает высоты -- тот блокирует движение, а в режиме давления получает
;  10 единиц урона раз в четыре тика.
; ---------------------------------------------------------------------------
P_ChangeSector:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    imul    esi, ecx, SECTOR_SIZE
    mov     r12d, edx                   ; crush
    mov     dword [nofit], 0
    mov     rbx, [sectors + rsi + SEC_THINGLIST]
.l:
    test    rbx, rbx
    jz      .done
    mov     rdi, [rbx + MO_SNEXT]       ; объект может исчезнуть
    ; пересчёт опор
    push    rdi
    mov     rcx, rbx
    call    P_CalcFloorCeiling
    pop     rdi
    ; стоящий на полу поднимается вместе с ним
    test    dword [rbx + MO_FLAGS], MF_NOCLIP
    jnz     .next
    mov     eax, [rbx + MO_Z]
    cmp     eax, [rbx + MO_FLOORZ]
    jge     .zok
    mov     eax, [rbx + MO_FLOORZ]
    mov     [rbx + MO_Z], eax
.zok:
    ; хватает ли высоты
    mov     eax, [rbx + MO_CEILINGZ]
    sub     eax, [rbx + MO_FLOORZ]
    mov     rdx, [rbx + MO_INFO]
    cmp     eax, [rdx + MI_HEIGHT]
    jge     .next
    ; не помещается
    test    dword [rbx + MO_FLAGS], MF_SHOOTABLE
    jz      .solidcheck
    cmp     dword [rbx + MO_HEALTH], 0
    jg      .alive
    ; труп расплющивает в кровь, он больше не мешает
    mov     dword [rbx + MO_HEIGHT], 0
    mov     dword [rbx + MO_RADIUS], 0
    jmp     .next
.alive:
    mov     dword [nofit], 1
    test    r12d, r12d
    jz      .next
    mov     eax, [leveltime]
    and     eax, 3
    jnz     .next
    push    rdi
    mov     rcx, rbx
    xor     rdx, rdx
    xor     r8, r8
    mov     r9d, 10
    call    P_DamageMobj
    pop     rdi
    ; брызги крови из-под потолка
    test    dword [rbx + MO_FLAGS], MF_NOBLOOD
    jnz     .next
    push    rdi
    mov     ecx, [rbx + MO_X]
    mov     edx, [rbx + MO_Y]
    mov     r8d, [rbx + MO_Z]
    mov     rax, [rbx + MO_INFO]
    mov     eax, [rax + MI_HEIGHT]
    shr     eax, 1
    add     r8d, eax
    mov     r9d, MT_BLOOD
    call    P_SpawnMobj
    pop     rdi
    jmp     .next
.solidcheck:
    test    dword [rbx + MO_FLAGS], MF_SOLID
    jz      .next
    mov     dword [nofit], 1
.next:
    mov     rbx, rdi
    jmp     .l
.done:
    mov     eax, [nofit]
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  EV_DoCeiling(ecx = тег, edx = тип) -> eax
; ---------------------------------------------------------------------------
EV_DoCeiling:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    mov     r12d, edx
    mov     r13d, ecx
    xor     edi, edi
    ; типы 2..5 сначала пробуют снять с паузы уже стоящий механизм
    cmp     r12d, CT_LOWERANDCRUSH
    jl      .scan
    mov     ecx, r13d
    call    EV_CeilingActivate
    mov     edi, eax
.scan:
    mov     edx, -1
.l:
    mov     ecx, r13d
    call    P_FindSectorFromTag
    cmp     eax, -1
    je      .done
    mov     edx, eax
    push    rdx
    imul    eax, edx, SECTOR_SIZE
    cmp     qword [sectors + rax + SEC_SPECIALDATA], 0
    jne     .next
    mov     ecx, edx
    mov     edx, r12d
    mov     r8d, r13d
    call    P_SpawnCeiling
    mov     edi, 1
.next:
    pop     rdx
    jmp     .l
.done:
    mov     eax, edi
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; P_SpawnCeiling(ecx = сектор, edx = тип, r8d = тег)
P_SpawnCeiling:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    mov     r12d, ecx
    mov     edi, edx
    mov     r13d, r8d
    xor     ebx, ebx
.find:
    imul    eax, ebx, CEIL_SIZE
    cmp     dword [ceilmoves + rax + CL_INUSE], 0
    je      .found
    inc     ebx
    cmp     ebx, MAXCEILINGS
    jb      .find
    jmp     .done
.found:
    imul    eax, ebx, CEIL_SIZE
    lea     rsi, [ceilmoves]
    add     rsi, rax
    mov     dword [rsi + CL_INUSE], 1
    mov     [rsi + CL_SECTOR], r12d
    mov     [rsi + CL_TYPE], edi
    mov     [rsi + CL_TAG], r13d
    mov     dword [rsi + CL_CRUSH], 0
    mov     dword [rsi + CL_SPEED], CEILSPEED
    imul    eax, r12d, SECTOR_SIZE
    mov     [sectors + rax + SEC_SPECIALDATA], rsi
    ; верхняя граница -- текущая высота потолка
    mov     ecx, [sectors + rax + SEC_CEILH]
    mov     [rsi + CL_TOPH], ecx
    mov     ecx, [sectors + rax + SEC_FLOORH]
    mov     [rsi + CL_BOTH], ecx

    cmp     edi, CT_LOWERTOFLOOR
    jne     .t1
    mov     dword [rsi + CL_DIR], -1
    jmp     .snd
.t1:
    cmp     edi, CT_RAISETOHIGHEST
    jne     .t2
    push    rsi
    mov     ecx, r12d
    call    P_FindHighestCeilingSurrounding
    pop     rsi
    mov     [rsi + CL_TOPH], eax
    mov     dword [rsi + CL_DIR], 1
    jmp     .snd
.t2:
    ; всё остальное давит: нижняя граница -- пол + 8
    add     dword [rsi + CL_BOTH], 8*FRACUNIT
    mov     dword [rsi + CL_DIR], -1
    mov     dword [rsi + CL_CRUSH], 1
    cmp     edi, CT_FASTCRUSH
    jne     .snd
    mov     dword [rsi + CL_SPEED], CEILSPEED*2
.snd:
    cmp     edi, CT_SILENTCRUSH
    je      .done
    push    rsi
    mov     rcx, [playermo]
    mov     edx, sfx_stnmov
    call    S_StartSound
    pop     rsi
.done:
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  EV_CeilingCrushStop(ecx = тег) -> eax -- поставить давящий потолок на паузу
; ---------------------------------------------------------------------------
EV_CeilingCrushStop:
    push    rbx
    push    rsi
    mov     edx, ecx
    xor     eax, eax
    xor     ebx, ebx
.l:
    imul    esi, ebx, CEIL_SIZE
    lea     rsi, [ceilmoves + rsi]
    cmp     dword [rsi + CL_INUSE], 0
    je      .next
    cmp     [rsi + CL_TAG], edx
    jne     .next
    cmp     dword [rsi + CL_DIR], 0
    je      .next
    mov     ecx, [rsi + CL_DIR]
    mov     [rsi + CL_OLDDIR], ecx
    mov     dword [rsi + CL_DIR], 0
    mov     eax, 1
.next:
    inc     ebx
    cmp     ebx, MAXCEILINGS
    jb      .l
    pop     rsi
    pop     rbx
    ret

; EV_CeilingActivate(ecx = тег) -> eax -- снять с паузы
EV_CeilingActivate:
    push    rbx
    push    rsi
    mov     edx, ecx
    xor     eax, eax
    xor     ebx, ebx
.l:
    imul    esi, ebx, CEIL_SIZE
    lea     rsi, [ceilmoves + rsi]
    cmp     dword [rsi + CL_INUSE], 0
    je      .next
    cmp     [rsi + CL_TAG], edx
    jne     .next
    cmp     dword [rsi + CL_DIR], 0
    jne     .next
    mov     ecx, [rsi + CL_OLDDIR]
    mov     [rsi + CL_DIR], ecx
    mov     eax, 1
.next:
    inc     ebx
    cmp     ebx, MAXCEILINGS
    jb      .l
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  T_MoveCeilings -- тик потолков
; ---------------------------------------------------------------------------
T_MoveCeilings:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    xor     ebx, ebx
.l:
    imul    esi, ebx, CEIL_SIZE
    lea     rsi, [ceilmoves + rsi]
    cmp     dword [rsi + CL_INUSE], 0
    je      .next
    mov     r12d, [rsi + CL_SECTOR]
    mov     edi, r12d
    imul    edi, SECTOR_SIZE
    cmp     dword [rsi + CL_DIR], 0
    je      .next                       ; пауза
    jl      .down

    ; --- вверх ---
    mov     eax, [sectors + rdi + SEC_CEILH]
    add     eax, [rsi + CL_SPEED]
    cmp     eax, [rsi + CL_TOPH]
    jl      .upset
    mov     eax, [rsi + CL_TOPH]
    mov     [sectors + rdi + SEC_CEILH], eax
    push    rsi
    mov     ecx, r12d
    xor     edx, edx
    call    P_ChangeSector
    pop     rsi
    ; давящий потолок разворачивается, остальные останавливаются
    cmp     dword [rsi + CL_TYPE], CT_CRUSHANDRAISE
    je      .revdown
    cmp     dword [rsi + CL_TYPE], CT_FASTCRUSH
    je      .revdown
    cmp     dword [rsi + CL_TYPE], CT_SILENTCRUSH
    je      .revdown
    jmp     .finish
.revdown:
    mov     dword [rsi + CL_DIR], -1
    mov     dword [rsi + CL_CRUSH], 1
    jmp     .next
.upset:
    mov     [sectors + rdi + SEC_CEILH], eax
    push    rsi
    mov     ecx, r12d
    xor     edx, edx
    call    P_ChangeSector
    pop     rsi
    jmp     .next

    ; --- вниз ---
.down:
    mov     eax, [sectors + rdi + SEC_CEILH]
    sub     eax, [rsi + CL_SPEED]
    cmp     eax, [rsi + CL_BOTH]
    jg      .downset
    mov     eax, [rsi + CL_BOTH]
    mov     [sectors + rdi + SEC_CEILH], eax
    push    rsi
    mov     ecx, r12d
    xor     edx, edx
    call    P_ChangeSector
    pop     rsi
    ; давящий уходит обратно вверх, обычный останавливается
    cmp     dword [rsi + CL_TYPE], CT_LOWERANDCRUSH
    je      .finish
    cmp     dword [rsi + CL_TYPE], CT_LOWERTOFLOOR
    je      .finish
    mov     dword [rsi + CL_DIR], 1
    mov     dword [rsi + CL_CRUSH], 0
    mov     dword [rsi + CL_SPEED], CEILSPEED
    cmp     dword [rsi + CL_TYPE], CT_FASTCRUSH
    jne     .next
    mov     dword [rsi + CL_SPEED], CEILSPEED*2
    jmp     .next
.downset:
    mov     [sectors + rdi + SEC_CEILH], eax
    push    rsi
    mov     ecx, r12d
    mov     edx, [rsi + CL_CRUSH]
    call    P_ChangeSector
    pop     rsi
    test    eax, eax
    jz      .next
    ; что-то мешает: давящий продолжает медленно, обычный откатывается
    cmp     dword [rsi + CL_CRUSH], 0
    jne     .slow
    mov     eax, [sectors + rdi + SEC_CEILH]
    add     eax, [rsi + CL_SPEED]
    mov     [sectors + rdi + SEC_CEILH], eax
    jmp     .next
.slow:
    cmp     dword [rsi + CL_TYPE], CT_SILENTCRUSH
    je      .next
    mov     dword [rsi + CL_SPEED], CEILSPEED/8
    jmp     .next

.finish:
    mov     dword [rsi + CL_INUSE], 0
    mov     qword [sectors + rdi + SEC_SPECIALDATA], 0
    push    rsi
    mov     rcx, [playermo]
    mov     edx, sfx_pstop
    call    S_StartSound
    pop     rsi
.next:
    inc     ebx
    cmp     ebx, MAXCEILINGS
    jb      .l
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  EV_BuildStairs(ecx = тег, edx = тип) -> eax
;    тип 0 -- ступень 8 единиц, медленно; тип 1 -- ступень 16, быстро
;
;  Как в p_floor.c: от помеченного сектора идём по двусторонним линиям к
;  соседу с тем же флэтом пола и поднимаем его на ступень выше предыдущего.
; ---------------------------------------------------------------------------
EV_BuildStairs:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r14d, ecx                   ; тег
    ; шаг и скорость
    mov     r15d, 8*FRACUNIT
    mov     r13d, FRACUNIT/4
    test    edx, edx
    jz      .speedok
    mov     r15d, 16*FRACUNIT
    mov     r13d, FRACUNIT*4
.speedok:
    xor     r12d, r12d                  ; было ли срабатывание
    mov     edx, -1
.seed:
    mov     ecx, r14d
    call    P_FindSectorFromTag
    cmp     eax, -1
    je      .done
    mov     edx, eax
    push    rdx
    mov     ebx, eax                    ; текущий сектор ступени
    imul    eax, ebx, SECTOR_SIZE
    cmp     qword [sectors + rax + SEC_SPECIALDATA], 0
    jne     .nextseed
    mov     r12d, 1
    mov     esi, [sectors + rax + SEC_FLOORH]   ; высота предыдущей ступени
    mov     edi, [sectors + rax + SEC_FLOORPIC] ; флэт цепочки
.step:
    add     esi, r15d
    mov     ecx, ebx
    mov     edx, esi
    mov     r8d, r13d
    call    P_SpawnStairStep
    ; ищем следующий сектор цепочки
    mov     ecx, ebx
    mov     edx, edi
    call    P_NextStairSector
    cmp     eax, -1
    je      .nextseed
    mov     ebx, eax
    jmp     .step
.nextseed:
    pop     rdx
    jmp     .seed
.done:
    mov     eax, r12d
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; P_SpawnStairStep(ecx = сектор, edx = целевая высота, r8d = скорость)
P_SpawnStairStep:
    push    rbx
    push    rsi
    push    r12
    push    r13
    push    r14
    mov     r12d, ecx
    mov     r13d, edx
    mov     r14d, r8d
    xor     ebx, ebx
.find:
    imul    eax, ebx, FLOOR_SIZE
    cmp     dword [floormoves + rax + FL_INUSE], 0
    je      .found
    inc     ebx
    cmp     ebx, MAXFLOORS
    jb      .find
    jmp     .done
.found:
    imul    eax, ebx, FLOOR_SIZE
    lea     rsi, [floormoves]
    add     rsi, rax
    mov     dword [rsi + FL_INUSE], 1
    mov     [rsi + FL_SECTOR], r12d
    mov     dword [rsi + FL_TYPE], 2
    mov     dword [rsi + FL_DIR], 1
    mov     [rsi + FL_DEST], r13d
    mov     [rsi + FL_SPEED], r14d
    mov     dword [rsi + FL_CRUSH], 0
    imul    eax, r12d, SECTOR_SIZE
    mov     [sectors + rax + SEC_SPECIALDATA], rsi
.done:
    pop     r14
    pop     r13
    pop     r12
    pop     rsi
    pop     rbx
    ret

; P_NextStairSector(ecx = сектор, edx = флэт) -> eax = сектор или -1
P_NextStairSector:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    mov     r12d, ecx
    mov     r13d, edx
    imul    edi, ecx, SECTOR_SIZE
    xor     ebx, ebx
.l:
    cmp     ebx, [sectors + rdi + SEC_LINECOUNT]
    jae     .none
    mov     rsi, [sectors + rdi + SEC_LINES]
    mov     eax, [rsi + rbx*4]
    imul    eax, LINE_SIZE
    ; ступень продолжается только через двусторонние линии
    cmp     dword [lines + rax + LN_BACKSEC], -1
    je      .next
    cmp     dword [lines + rax + LN_FRONTSEC], r12d
    jne     .next                       ; наружу идём только с лицевой стороны
    mov     ecx, [lines + rax + LN_BACKSEC]
    imul    eax, ecx, SECTOR_SIZE
    cmp     [sectors + rax + SEC_FLOORPIC], r13d
    jne     .next
    cmp     qword [sectors + rax + SEC_SPECIALDATA], 0
    jne     .next
    mov     eax, ecx
    jmp     .out
.next:
    inc     ebx
    jmp     .l
.none:
    mov     eax, -1
.out:
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
