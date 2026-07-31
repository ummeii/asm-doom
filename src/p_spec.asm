; ===========================================================================
;  p_spec.asm -- двери, лифты, полы, переключатели, телепорты, урон-секторы
; ===========================================================================

%define MAXDOORS    64
%define MAXPLATS    64
%define MAXFLOORS   64
%define MAXLIGHTS   64

%define VDOORSPEED  (FRACUNIT*2)
%define VDOORWAIT   150
%define PLATSPEED   FRACUNIT
%define PLATWAIT    3
%define FLOORSPEED  FRACUNIT

; --- дверь ---
%define DR_SECTOR   0
%define DR_TYPE     4
%define DR_TOPH     8
%define DR_SPEED    12
%define DR_DIR      16
%define DR_TOPWAIT  20
%define DR_COUNT    24
%define DR_INUSE    28
%define DOOR_SIZE   32

; --- лифт ---
%define PL_SECTOR   0
%define PL_SPEED    4
%define PL_LOW      8
%define PL_HIGH     12
%define PL_WAIT     16
%define PL_COUNT    20
%define PL_STATUS   24
%define PL_OLDSTAT  28
%define PL_TAG      32
%define PL_TYPE     36
%define PL_INUSE    40
%define PLAT_SIZE   48

; --- движение пола ---
%define FL_SECTOR   0
%define FL_TYPE     4
%define FL_DIR      8
%define FL_DEST     12
%define FL_SPEED    16
%define FL_CRUSH    20
%define FL_INUSE    24
%define FLOOR_SIZE  32

; --- освещение ---
%define LT_SECTOR   0
%define LT_TYPE     4
%define LT_COUNT    8
%define LT_MAXLIGHT 12
%define LT_MINLIGHT 16
%define LT_MAXTIME  20
%define LT_MINTIME  24
%define LT_INUSE    28
%define LIGHT_SIZE  32

; статусы лифта
%define P_UP        0
%define P_DOWN      1
%define P_WAITING   2
%define P_IN_STASIS 3

; ---------------------------------------------------------------------------
;  P_InitSpecials -- очистка и запуск постоянных эффектов
; ---------------------------------------------------------------------------
P_InitSpecials:
    push    rbx
    call    P_InitCeilings
    push    rsi
    xor     ebx, ebx
.clr:
    imul    eax, ebx, DOOR_SIZE
    mov     dword [doors + rax + DR_INUSE], 0
    imul    eax, ebx, PLAT_SIZE
    mov     dword [plats + rax + PL_INUSE], 0
    imul    eax, ebx, FLOOR_SIZE
    mov     dword [floormoves + rax + FL_INUSE], 0
    imul    eax, ebx, LIGHT_SIZE
    mov     dword [lightfx + rax + LT_INUSE], 0
    inc     ebx
    cmp     ebx, MAXDOORS
    jb      .clr
    mov     dword [totalsecret], 0
    mov     byte [g_exitlevel], 0

    ; эффекты секторов
    xor     ebx, ebx
.sec:
    cmp     ebx, [numsectors]
    jae     .done
    imul    esi, ebx, SECTOR_SIZE
    mov     eax, [sectors + rsi + SEC_SPECIAL]
    test    eax, eax
    jz      .secnext
    cmp     eax, 9
    jne     .nosecret
    inc     dword [totalsecret]
    jmp     .secnext
.nosecret:
    ; мигающий свет
    cmp     eax, 1
    je      .blink
    cmp     eax, 2
    je      .blink
    cmp     eax, 3
    je      .blink
    cmp     eax, 12
    je      .blink
    cmp     eax, 13
    je      .blink
    cmp     eax, 17
    je      .blink
    jmp     .secnext
.blink:
    mov     ecx, ebx
    mov     edx, eax
    call    P_SpawnLightFlash
.secnext:
    inc     ebx
    jmp     .sec
.done:
    pop     rsi
    pop     rbx
    ret

; P_SpawnLightFlash(ecx = сектор, edx = тип)
P_SpawnLightFlash:
    push    rbx
    push    rsi
    xor     ebx, ebx
.find:
    imul    eax, ebx, LIGHT_SIZE
    cmp     dword [lightfx + rax + LT_INUSE], 0
    je      .found
    inc     ebx
    cmp     ebx, MAXLIGHTS
    jb      .find
    jmp     .done
.found:
    imul    esi, ebx, LIGHT_SIZE
    mov     dword [lightfx + rsi + LT_INUSE], 1
    mov     [lightfx + rsi + LT_SECTOR], ecx
    mov     [lightfx + rsi + LT_TYPE], edx
    imul    eax, ecx, SECTOR_SIZE
    mov     edx, [sectors + rax + SEC_LIGHT]
    mov     [lightfx + rsi + LT_MAXLIGHT], edx
    ; минимум -- самый тёмный соседний
    push    rcx
    call    P_FindMinSurroundingLight
    pop     rcx
    mov     [lightfx + rsi + LT_MINLIGHT], eax
    mov     dword [lightfx + rsi + LT_MAXTIME], 64
    mov     dword [lightfx + rsi + LT_MINTIME], 7
    mov     dword [lightfx + rsi + LT_COUNT], 1
.done:
    pop     rsi
    pop     rbx
    ret

; P_FindMinSurroundingLight(ecx = сектор) -> eax
P_FindMinSurroundingLight:
    push    rbx
    push    rsi
    push    rdi
    imul    esi, ecx, SECTOR_SIZE
    mov     eax, [sectors + rsi + SEC_LIGHT]
    mov     edi, eax
    mov     r9, [sectors + rsi + SEC_LINES]
    xor     ebx, ebx
.l:
    cmp     ebx, [sectors + rsi + SEC_LINECOUNT]
    jae     .done
    mov     eax, [r9 + rbx*4]
    imul    eax, LINE_SIZE
    mov     edx, [lines + rax + LN_FRONTSEC]
    cmp     edx, ecx
    jne     .have
    mov     edx, [lines + rax + LN_BACKSEC]
.have:
    cmp     edx, -1
    je      .next
    imul    edx, SECTOR_SIZE
    mov     eax, [sectors + rdx + SEC_LIGHT]
    cmp     eax, edi
    jge     .next
    mov     edi, eax
.next:
    inc     ebx
    jmp     .l
.done:
    mov     eax, edi
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  Поиск секторов по тегу: P_FindSectorFromTag(ecx = тег, edx = с какого)
;   -> eax = индекс сектора или -1
; ---------------------------------------------------------------------------
P_FindSectorFromTag:
    inc     edx
.l:
    cmp     edx, [numsectors]
    jae     .none
    imul    eax, edx, SECTOR_SIZE
    cmp     [sectors + rax + SEC_TAG], ecx
    je      .found
    inc     edx
    jmp     .l
.found:
    mov     eax, edx
    ret
.none:
    mov     eax, -1
    ret

; ---------------------------------------------------------------------------
;  P_FindLowestFloorSurrounding(ecx = сектор) -> eax
; ---------------------------------------------------------------------------
P_FindLowestFloorSurrounding:
    push    rbx
    push    rsi
    push    rdi
    imul    esi, ecx, SECTOR_SIZE
    mov     edi, [sectors + rsi + SEC_FLOORH]
    mov     r9, [sectors + rsi + SEC_LINES]
    xor     ebx, ebx
.l:
    cmp     ebx, [sectors + rsi + SEC_LINECOUNT]
    jae     .done
    mov     eax, [r9 + rbx*4]
    imul    eax, LINE_SIZE
    mov     edx, [lines + rax + LN_FRONTSEC]
    cmp     edx, ecx
    jne     .have
    mov     edx, [lines + rax + LN_BACKSEC]
.have:
    cmp     edx, -1
    je      .next
    imul    edx, SECTOR_SIZE
    mov     eax, [sectors + rdx + SEC_FLOORH]
    cmp     eax, edi
    jge     .next
    mov     edi, eax
.next:
    inc     ebx
    jmp     .l
.done:
    mov     eax, edi
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_FindHighestFloorSurrounding(ecx = сектор) -> eax
; ---------------------------------------------------------------------------
P_FindHighestFloorSurrounding:
    push    rbx
    push    rsi
    push    rdi
    imul    esi, ecx, SECTOR_SIZE
    mov     edi, MININT
    mov     r9, [sectors + rsi + SEC_LINES]
    xor     ebx, ebx
.l:
    cmp     ebx, [sectors + rsi + SEC_LINECOUNT]
    jae     .done
    mov     eax, [r9 + rbx*4]
    imul    eax, LINE_SIZE
    mov     edx, [lines + rax + LN_FRONTSEC]
    cmp     edx, ecx
    jne     .have
    mov     edx, [lines + rax + LN_BACKSEC]
.have:
    cmp     edx, -1
    je      .next
    imul    edx, SECTOR_SIZE
    mov     eax, [sectors + rdx + SEC_FLOORH]
    cmp     eax, edi
    jle     .next
    mov     edi, eax
.next:
    inc     ebx
    jmp     .l
.done:
    mov     eax, edi
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_FindLowestCeilingSurrounding(ecx = сектор) -> eax
; ---------------------------------------------------------------------------
P_FindLowestCeilingSurrounding:
    push    rbx
    push    rsi
    push    rdi
    imul    esi, ecx, SECTOR_SIZE
    mov     edi, MAXINT
    mov     r9, [sectors + rsi + SEC_LINES]
    xor     ebx, ebx
.l:
    cmp     ebx, [sectors + rsi + SEC_LINECOUNT]
    jae     .done
    mov     eax, [r9 + rbx*4]
    imul    eax, LINE_SIZE
    mov     edx, [lines + rax + LN_FRONTSEC]
    cmp     edx, ecx
    jne     .have
    mov     edx, [lines + rax + LN_BACKSEC]
.have:
    cmp     edx, -1
    je      .next
    imul    edx, SECTOR_SIZE
    mov     eax, [sectors + rdx + SEC_CEILH]
    cmp     eax, edi
    jge     .next
    mov     edi, eax
.next:
    inc     ebx
    jmp     .l
.done:
    mov     eax, edi
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ===========================================================================
;  Двери
; ===========================================================================
; типы: 0 = normal (открыть-подождать-закрыть), 1 = open stay,
;       2 = close stay, 3 = close wait open
%define DT_NORMAL   0
%define DT_OPEN     1
%define DT_CLOSE    2

; EV_DoDoor(ecx = тег, edx = тип, r8d = скорость) -> eax
EV_DoDoor:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    mov     r12d, edx
    mov     r13d, r8d
    mov     esi, ecx
    xor     edi, edi                    ; сработало
    mov     edx, -1
.l:
    mov     ecx, esi
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
    call    P_SpawnDoor
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

; P_SpawnDoor(ecx = сектор, edx = тип, r8d = скорость)
P_SpawnDoor:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    mov     r12d, ecx
    mov     edi, edx
    mov     esi, r8d
    xor     ebx, ebx
.find:
    imul    eax, ebx, DOOR_SIZE
    cmp     dword [doors + rax + DR_INUSE], 0
    je      .found
    inc     ebx
    cmp     ebx, MAXDOORS
    jb      .find
    jmp     .done
.found:
    imul    eax, ebx, DOOR_SIZE
    lea     r9, [doors]
    add     r9, rax
    mov     dword [r9 + DR_INUSE], 1
    mov     [r9 + DR_SECTOR], r12d
    mov     [r9 + DR_TYPE], edi
    mov     [r9 + DR_SPEED], esi
    mov     dword [r9 + DR_TOPWAIT], VDOORWAIT
    imul    eax, r12d, SECTOR_SIZE
    mov     [sectors + rax + SEC_SPECIALDATA], r9
    ; целевая высота = минимальный соседний потолок - 4
    push    r9
    mov     ecx, r12d
    call    P_FindLowestCeilingSurrounding
    pop     r9
    sub     eax, 4*FRACUNIT
    mov     [r9 + DR_TOPH], eax
    cmp     edi, DT_CLOSE
    je      .close
    mov     dword [r9 + DR_DIR], 1      ; вверх
    push    r9
    mov     rcx, [playermo]
    mov     edx, sfx_doropn
    call    S_StartSound
    pop     r9
    jmp     .done
.close:
    imul    eax, r12d, SECTOR_SIZE
    mov     eax, [sectors + rax + SEC_CEILH]
    mov     [r9 + DR_TOPH], eax
    mov     dword [r9 + DR_DIR], -1
    push    r9
    mov     rcx, [playermo]
    mov     edx, sfx_dorcls
    call    S_StartSound
    pop     r9
.done:
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; T_VerticalDoor -- тик всех дверей
T_VerticalDoors:
    push    rbx
    push    rsi
    push    rdi
    xor     ebx, ebx
.l:
    imul    esi, ebx, DOOR_SIZE
    lea     rsi, [doors + rsi]
    cmp     dword [rsi + DR_INUSE], 0
    je      .next
    mov     edi, [rsi + DR_SECTOR]
    imul    edi, SECTOR_SIZE
    mov     eax, [rsi + DR_DIR]
    test    eax, eax
    jz      .waiting
    js      .godown
    ; --- вверх ---
    mov     eax, [sectors + rdi + SEC_CEILH]
    add     eax, [rsi + DR_SPEED]
    cmp     eax, [rsi + DR_TOPH]
    jl      .upok
    mov     eax, [rsi + DR_TOPH]
    mov     [sectors + rdi + SEC_CEILH], eax
    cmp     dword [rsi + DR_TYPE], DT_OPEN
    je      .remove
    mov     dword [rsi + DR_DIR], 0
    mov     eax, [rsi + DR_TOPWAIT]
    mov     [rsi + DR_COUNT], eax
    jmp     .next
.upok:
    mov     [sectors + rdi + SEC_CEILH], eax
    jmp     .next
.godown:
    ; --- вниз ---
    mov     eax, [sectors + rdi + SEC_CEILH]
    sub     eax, [rsi + DR_SPEED]
    ; проверка на раздавливание
    mov     ecx, [sectors + rdi + SEC_FLOORH]
    cmp     eax, ecx
    jg      .downok
    mov     [sectors + rdi + SEC_CEILH], ecx
    jmp     .remove
.downok:
    ; если под дверью кто-то есть -- открыть обратно
    push    rsi
    push    rdi
    mov     ecx, [rsi + DR_SECTOR]
    mov     edx, eax
    call    P_CheckDoorBlocked
    pop     rdi
    pop     rsi
    test    eax, eax
    jz      .movedown
    mov     dword [rsi + DR_DIR], 1
    jmp     .next
.movedown:
    mov     eax, [sectors + rdi + SEC_CEILH]
    sub     eax, [rsi + DR_SPEED]
    mov     [sectors + rdi + SEC_CEILH], eax
    jmp     .next
.waiting:
    dec     dword [rsi + DR_COUNT]
    jg      .next
    mov     dword [rsi + DR_DIR], -1
    push    rsi
    mov     rcx, [playermo]
    mov     edx, sfx_dorcls
    call    S_StartSound
    pop     rsi
    jmp     .next
.remove:
    mov     dword [rsi + DR_INUSE], 0
    mov     qword [sectors + rdi + SEC_SPECIALDATA], 0
.next:
    inc     ebx
    cmp     ebx, MAXDOORS
    jb      .l
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; P_CheckDoorBlocked(ecx = сектор, edx = новая высота потолка) -> eax
P_CheckDoorBlocked:
    push    rbx
    push    rsi
    imul    esi, ecx, SECTOR_SIZE
    mov     rbx, [sectors + rsi + SEC_THINGLIST]
.l:
    test    rbx, rbx
    jz      .no
    test    dword [rbx + MO_FLAGS], MF_SOLID
    jz      .next
    mov     eax, [rbx + MO_Z]
    add     eax, [rbx + MO_HEIGHT]
    cmp     edx, eax
    jl      .yes
.next:
    mov     rbx, [rbx + MO_SNEXT]
    jmp     .l
.yes:
    mov     eax, 1
    pop     rsi
    pop     rbx
    ret
.no:
    xor     eax, eax
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  EV_VerticalDoor -- ручная дверь (тип DR), rcx = линия, rdx = mobj
; ---------------------------------------------------------------------------
EV_VerticalDoor:
    push    rbx
    push    rsi
    push    rdi
    mov     ebx, ecx                    ; смещение линии
    mov     rsi, rdx
    ; проверка ключей
    mov     eax, [lines + rbx + LN_SPECIAL]
    cmp     eax, 26
    je      .needblue
    cmp     eax, 32
    je      .needblue
    cmp     eax, 27
    je      .needyellow
    cmp     eax, 34
    je      .needyellow
    cmp     eax, 28
    je      .needred
    cmp     eax, 33
    je      .needred
    jmp     .nokey
.needblue:
    cmp     dword [player + PL_CARDS + it_bluecard*4], 0
    jne     .nokey
    mov     rcx, str_needblue
    call    P_SetMessage
    jmp     .done
.needyellow:
    cmp     dword [player + PL_CARDS + it_yellowcard*4], 0
    jne     .nokey
    mov     rcx, str_needyellow
    call    P_SetMessage
    jmp     .done
.needred:
    cmp     dword [player + PL_CARDS + it_redcard*4], 0
    jne     .nokey
    mov     rcx, str_needred
    call    P_SetMessage
    jmp     .done
.nokey:
    ; сектор за линией
    mov     edi, [lines + rbx + LN_BACKSEC]
    cmp     edi, -1
    je      .done
    imul    eax, edi, SECTOR_SIZE
    mov     r9, [sectors + rax + SEC_SPECIALDATA]
    test    r9, r9
    jz      .newdoor
    ; уже движется -- перевернуть
    cmp     dword [r9 + DR_DIR], -1
    jne     .reverse
    mov     dword [r9 + DR_DIR], 1
    jmp     .done
.reverse:
    mov     dword [r9 + DR_DIR], -1
    jmp     .done
.newdoor:
    mov     ecx, edi
    mov     edx, DT_NORMAL
    mov     eax, [lines + rbx + LN_SPECIAL]
    mov     r8d, VDOORSPEED
    cmp     eax, 117
    jne     .normspeed
    mov     r8d, VDOORSPEED*4
    mov     edx, DT_NORMAL
.normspeed:
    call    P_SpawnDoor
.done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ===========================================================================
;  Лифты (платформы)
; ===========================================================================
; EV_DoPlat(ecx = тег, edx = тип, r8d = сколько ждать) -> eax
;   тип 0 = опустить и вернуть, 1 = поднять к ближайшему полу
EV_DoPlat:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    mov     r12d, edx
    mov     esi, ecx
    xor     edi, edi
    mov     edx, -1
.l:
    mov     ecx, esi
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
    call    P_SpawnPlat
    mov     edi, 1
.next:
    pop     rdx
    jmp     .l
.done:
    mov     eax, edi
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; P_SpawnPlat(ecx = сектор, edx = тип)
P_SpawnPlat:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    mov     r12d, ecx
    mov     edi, edx
    xor     ebx, ebx
.find:
    imul    eax, ebx, PLAT_SIZE
    cmp     dword [plats + rax + PL_INUSE], 0
    je      .found
    inc     ebx
    cmp     ebx, MAXPLATS
    jb      .find
    jmp     .done
.found:
    imul    eax, ebx, PLAT_SIZE
    lea     rsi, [plats]
    add     rsi, rax
    mov     dword [rsi + PL_INUSE], 1
    mov     [rsi + PL_SECTOR], r12d
    mov     [rsi + PL_TYPE], edi
    mov     dword [rsi + PL_SPEED], PLATSPEED
    mov     dword [rsi + PL_WAIT], PLATWAIT*35
    imul    eax, r12d, SECTOR_SIZE
    mov     [sectors + rax + SEC_SPECIALDATA], rsi
    mov     ecx, [sectors + rax + SEC_FLOORH]
    mov     [rsi + PL_HIGH], ecx
    push    rsi
    mov     ecx, r12d
    call    P_FindLowestFloorSurrounding
    pop     rsi
    mov     [rsi + PL_LOW], eax
    cmp     eax, [rsi + PL_HIGH]
    jle     .lowok
    mov     eax, [rsi + PL_HIGH]
    mov     [rsi + PL_LOW], eax
.lowok:
    mov     dword [rsi + PL_STATUS], P_DOWN
    push    rsi
    mov     rcx, [playermo]
    mov     edx, sfx_pstart
    call    S_StartSound
    pop     rsi
.done:
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; T_PlatRaise -- тик лифтов
T_Plats:
    push    rbx
    push    rsi
    push    rdi
    xor     ebx, ebx
.l:
    imul    esi, ebx, PLAT_SIZE
    lea     rsi, [plats + rsi]
    cmp     dword [rsi + PL_INUSE], 0
    je      .next
    mov     edi, [rsi + PL_SECTOR]
    imul    edi, SECTOR_SIZE
    mov     eax, [rsi + PL_STATUS]
    cmp     eax, P_DOWN
    je      .down
    cmp     eax, P_UP
    je      .up
    ; ожидание
    dec     dword [rsi + PL_COUNT]
    jg      .next
    mov     eax, [sectors + rdi + SEC_FLOORH]
    cmp     eax, [rsi + PL_LOW]
    jne     .godown
    mov     dword [rsi + PL_STATUS], P_UP
    jmp     .snd
.godown:
    mov     dword [rsi + PL_STATUS], P_DOWN
.snd:
    push    rsi
    mov     rcx, [playermo]
    mov     edx, sfx_pstart
    call    S_StartSound
    pop     rsi
    jmp     .next
.down:
    mov     eax, [sectors + rdi + SEC_FLOORH]
    sub     eax, [rsi + PL_SPEED]
    cmp     eax, [rsi + PL_LOW]
    jg      .dok
    mov     eax, [rsi + PL_LOW]
    mov     [sectors + rdi + SEC_FLOORH], eax
    mov     dword [rsi + PL_STATUS], P_WAITING
    mov     eax, [rsi + PL_WAIT]
    mov     [rsi + PL_COUNT], eax
    push    rsi
    mov     rcx, [playermo]
    mov     edx, sfx_pstop
    call    S_StartSound
    pop     rsi
    jmp     .next
.dok:
    mov     [sectors + rdi + SEC_FLOORH], eax
    jmp     .next
.up:
    mov     eax, [sectors + rdi + SEC_FLOORH]
    add     eax, [rsi + PL_SPEED]
    cmp     eax, [rsi + PL_HIGH]
    jl      .uok
    mov     eax, [rsi + PL_HIGH]
    mov     [sectors + rdi + SEC_FLOORH], eax
    ; лифт вернулся -- снимаем
    mov     dword [rsi + PL_INUSE], 0
    mov     qword [sectors + rdi + SEC_SPECIALDATA], 0
    push    rsi
    mov     rcx, [playermo]
    mov     edx, sfx_pstop
    call    S_StartSound
    pop     rsi
    jmp     .next
.uok:
    mov     [sectors + rdi + SEC_FLOORH], eax
    ; поднимаем объекты
    push    rsi
    mov     ecx, [rsi + PL_SECTOR]
    call    P_LiftThings
    pop     rsi
.next:
    inc     ebx
    cmp     ebx, MAXPLATS
    jb      .l
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; P_LiftThings(ecx = сектор) -- поднять объекты вместе с полом
P_LiftThings:
    push    rbx
    push    rsi
    imul    esi, ecx, SECTOR_SIZE
    mov     ecx, [sectors + rsi + SEC_FLOORH]
    mov     rbx, [sectors + rsi + SEC_THINGLIST]
.l:
    test    rbx, rbx
    jz      .done
    mov     [rbx + MO_FLOORZ], ecx
    cmp     [rbx + MO_Z], ecx
    jge     .next
    mov     [rbx + MO_Z], ecx
.next:
    mov     rbx, [rbx + MO_SNEXT]
    jmp     .l
.done:
    pop     rsi
    pop     rbx
    ret

; ===========================================================================
;  Движение полов
; ===========================================================================
; EV_DoFloor(ecx = тег, edx = тип) -> eax
;   0 = опустить до низшего соседнего, 1 = поднять до ближайшего потолка,
;   2 = поднять до высшего соседнего пола
EV_DoFloor:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    mov     r12d, edx
    mov     esi, ecx
    xor     edi, edi
    mov     edx, -1
.l:
    mov     ecx, esi
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
    call    P_SpawnFloor
    mov     edi, 1
.next:
    pop     rdx
    jmp     .l
.done:
    mov     eax, edi
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; P_SpawnFloor(ecx = сектор, edx = тип)
P_SpawnFloor:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    mov     r12d, ecx
    mov     edi, edx
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
    mov     [rsi + FL_TYPE], edi
    mov     dword [rsi + FL_SPEED], FLOORSPEED
    imul    eax, r12d, SECTOR_SIZE
    mov     [sectors + rax + SEC_SPECIALDATA], rsi
    cmp     edi, 0
    jne     .up
    push    rsi
    mov     ecx, r12d
    call    P_FindLowestFloorSurrounding
    pop     rsi
    mov     [rsi + FL_DEST], eax
    mov     dword [rsi + FL_DIR], -1
    jmp     .snd
.up:
    cmp     edi, 2
    jne     .toceil
    push    rsi
    mov     ecx, r12d
    call    P_FindHighestFloorSurrounding
    pop     rsi
    mov     [rsi + FL_DEST], eax
    mov     dword [rsi + FL_DIR], 1
    jmp     .snd
.toceil:
    imul    eax, r12d, SECTOR_SIZE
    mov     eax, [sectors + rax + SEC_CEILH]
    sub     eax, 8*FRACUNIT
    mov     [rsi + FL_DEST], eax
    mov     dword [rsi + FL_DIR], 1
.snd:
    push    rsi
    mov     rcx, [playermo]
    mov     edx, sfx_stnmov
    call    S_StartSound
    pop     rsi
.done:
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

T_Floors:
    push    rbx
    push    rsi
    push    rdi
    xor     ebx, ebx
.l:
    imul    esi, ebx, FLOOR_SIZE
    lea     rsi, [floormoves + rsi]
    cmp     dword [rsi + FL_INUSE], 0
    je      .next
    mov     edi, [rsi + FL_SECTOR]
    imul    edi, SECTOR_SIZE
    mov     eax, [sectors + rdi + SEC_FLOORH]
    cmp     dword [rsi + FL_DIR], 0
    jl      .down
    add     eax, [rsi + FL_SPEED]
    cmp     eax, [rsi + FL_DEST]
    jl      .setz
    mov     eax, [rsi + FL_DEST]
    mov     [sectors + rdi + SEC_FLOORH], eax
    jmp     .finish
.down:
    sub     eax, [rsi + FL_SPEED]
    cmp     eax, [rsi + FL_DEST]
    jg      .setz
    mov     eax, [rsi + FL_DEST]
    mov     [sectors + rdi + SEC_FLOORH], eax
    jmp     .finish
.setz:
    mov     [sectors + rdi + SEC_FLOORH], eax
    push    rsi
    mov     ecx, [rsi + FL_SECTOR]
    call    P_LiftThings
    pop     rsi
    jmp     .next
.finish:
    push    rsi
    mov     ecx, [rsi + FL_SECTOR]
    call    P_LiftThings
    pop     rsi
    mov     dword [rsi + FL_INUSE], 0
    mov     qword [sectors + rdi + SEC_SPECIALDATA], 0
    push    rsi
    mov     rcx, [playermo]
    mov     edx, sfx_pstop
    call    S_StartSound
    pop     rsi
.next:
    inc     ebx
    cmp     ebx, MAXFLOORS
    jb      .l
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ===========================================================================
;  Освещение
; ===========================================================================
T_Lights:
    push    rbx
    push    rsi
    push    rdi
    xor     ebx, ebx
.l:
    imul    esi, ebx, LIGHT_SIZE
    lea     rsi, [lightfx + rsi]
    cmp     dword [rsi + LT_INUSE], 0
    je      .next
    dec     dword [rsi + LT_COUNT]
    jg      .next
    mov     edi, [rsi + LT_SECTOR]
    imul    edi, SECTOR_SIZE
    mov     eax, [sectors + rdi + SEC_LIGHT]
    cmp     eax, [rsi + LT_MAXLIGHT]
    jne     .setmax
    mov     eax, [rsi + LT_MINLIGHT]
    mov     [sectors + rdi + SEC_LIGHT], eax
    call    P_Random
    and     eax, 7
    inc     eax
    imul    eax, [rsi + LT_MINTIME]
    shr     eax, 3
    inc     eax
    mov     [rsi + LT_COUNT], eax
    jmp     .next
.setmax:
    mov     eax, [rsi + LT_MAXLIGHT]
    mov     [sectors + rdi + SEC_LIGHT], eax
    call    P_Random
    and     eax, 7
    inc     eax
    imul    eax, [rsi + LT_MAXTIME]
    shr     eax, 3
    inc     eax
    mov     [rsi + LT_COUNT], eax
.next:
    inc     ebx
    cmp     ebx, MAXLIGHTS
    jb      .l
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ===========================================================================
;  Обработка линий
; ===========================================================================

; P_CrossSpecialLine(ecx = смещение линии, edx = сторона, r8 = mobj)
P_CrossSpecialLine:
    push    rbx
    push    rsi
    push    rdi
    mov     ebx, ecx
    mov     rdi, r8
    mov     esi, [lines + rbx + LN_SPECIAL]
    ; монстрам доступна только часть линий
    cmp     qword [rdi + MO_PLAYER], 0
    jne     .player
    cmp     esi, 39
    je      .ok
    cmp     esi, 97
    je      .ok
    cmp     esi, 4
    je      .ok
    cmp     esi, 10
    je      .ok
    jmp     .done
.player:
.ok:
    mov     ecx, [lines + rbx + LN_TAG]
    cmp     esi, 2
    jne     .c3
    mov     edx, DT_OPEN
    mov     r8d, VDOORSPEED
    call    EV_DoDoor
    jmp     .clear
.c3:
    cmp     esi, 3
    jne     .c4
    mov     edx, DT_CLOSE
    mov     r8d, VDOORSPEED
    call    EV_DoDoor
    jmp     .clear
.c4:
    cmp     esi, 4
    jne     .c10
    mov     edx, DT_NORMAL
    mov     r8d, VDOORSPEED
    call    EV_DoDoor
    jmp     .clear
.c10:
    cmp     esi, 10
    je      .plat
    cmp     esi, 88
    jne     .c19
.plat:
    xor     edx, edx
    call    EV_DoPlat
    cmp     esi, 88
    je      .done                       ; WR -- повторяемая
    jmp     .clear
.c19:
    cmp     esi, 19
    jne     .c22
    xor     edx, edx
    call    EV_DoFloor
    jmp     .clear
.c22:
    cmp     esi, 22
    jne     .c39
    mov     edx, 2
    call    EV_DoFloor
    jmp     .clear
.c39:
    cmp     esi, 39
    je      .tele
    cmp     esi, 97
    jne     .c52
.tele:
    mov     rcx, rdi
    mov     edx, ebx
    call    EV_Teleport
    cmp     esi, 97
    je      .done
    jmp     .clear
.c52:
    cmp     esi, 52
    jne     .cceil
    mov     byte [g_exitlevel], 1
    jmp     .clear
.cceil:
    ; давящие потолки
    cmp     esi, 6
    jne     .c25
    mov     edx, CT_FASTCRUSH
    call    EV_DoCeiling
    jmp     .clear
.c25:
    cmp     esi, 25
    jne     .c73
    mov     edx, CT_CRUSHANDRAISE
    call    EV_DoCeiling
    jmp     .clear
.c73:
    cmp     esi, 73
    jne     .c77
    mov     edx, CT_CRUSHANDRAISE
    call    EV_DoCeiling
    jmp     .done                       ; WR -- повторяемая
.c77:
    cmp     esi, 77
    jne     .c40
    mov     edx, CT_FASTCRUSH
    call    EV_DoCeiling
    jmp     .done
.c40:
    cmp     esi, 40
    jne     .c44
    mov     edx, CT_RAISETOHIGHEST
    call    EV_DoCeiling
    jmp     .clear
.c44:
    cmp     esi, 44
    jne     .c57
    mov     edx, CT_LOWERANDCRUSH
    call    EV_DoCeiling
    jmp     .clear
.c57:
    cmp     esi, 57
    je      .stopcrush
    cmp     esi, 74
    jne     .c8
    call    EV_CeilingCrushStop
    jmp     .done                       ; WR
.stopcrush:
    call    EV_CeilingCrushStop
    jmp     .clear
.c8:
    ; лестницы
    cmp     esi, 8
    jne     .c100
    xor     edx, edx
    call    EV_BuildStairs
    jmp     .clear
.c100:
    cmp     esi, 100
    jne     .done
    mov     edx, 1
    call    EV_BuildStairs
    jmp     .clear
.clear:
    mov     dword [lines + rbx + LN_SPECIAL], 0
.done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; P_UseSpecialLine(ecx = смещение линии, edx = сторона, r8 = mobj) -> eax
P_UseSpecialLine:
    push    rbx
    push    rsi
    push    rdi
    mov     ebx, ecx
    mov     rdi, r8
    mov     esi, [lines + rbx + LN_SPECIAL]
    ; ручные двери
    cmp     esi, 1
    je      .manual
    cmp     esi, 26
    je      .manual
    cmp     esi, 27
    je      .manual
    cmp     esi, 28
    je      .manual
    cmp     esi, 117
    je      .manual
    cmp     esi, 31
    je      .manual
    cmp     esi, 32
    je      .manual
    cmp     esi, 33
    je      .manual
    cmp     esi, 34
    je      .manual
    ; остальное -- только игроку
    cmp     qword [rdi + MO_PLAYER], 0
    je      .fail
    mov     ecx, [lines + rbx + LN_TAG]
    cmp     esi, 29
    jne     .s31
    mov     edx, DT_NORMAL
    mov     r8d, VDOORSPEED
    call    EV_DoDoor
    jmp     .switch
.s31:
    cmp     esi, 103
    jne     .s21
    mov     edx, DT_OPEN
    mov     r8d, VDOORSPEED
    call    EV_DoDoor
    jmp     .switch
.s21:
    cmp     esi, 21
    je      .doplat
    cmp     esi, 62
    jne     .s23
.doplat:
    xor     edx, edx
    call    EV_DoPlat
    jmp     .switch
.s23:
    cmp     esi, 23
    je      .dofloordn
    cmp     esi, 60
    jne     .s18
.dofloordn:
    xor     edx, edx
    call    EV_DoFloor
    jmp     .switch
.s18:
    cmp     esi, 18
    jne     .s49
    mov     edx, 2
    call    EV_DoFloor
    jmp     .switch
.s49:
    cmp     esi, 49
    jne     .s41
    mov     edx, CT_LOWERANDCRUSH
    call    EV_DoCeiling
    jmp     .switch
.s41:
    cmp     esi, 41
    jne     .s7
    mov     edx, CT_LOWERTOFLOOR
    call    EV_DoCeiling
    jmp     .switch
.s7:
    cmp     esi, 7
    jne     .s127
    xor     edx, edx
    call    EV_BuildStairs
    jmp     .switch
.s127:
    cmp     esi, 127
    jne     .s11
    mov     edx, 1
    call    EV_BuildStairs
    jmp     .switch
.s11:
    cmp     esi, 11
    je      .exit
    cmp     esi, 51
    jne     .fail
    mov     byte [g_secretexit], 1
.exit:
    mov     byte [g_exitlevel], 1
    jmp     .switch
.manual:
    mov     ecx, ebx
    mov     rdx, rdi
    call    EV_VerticalDoor
    mov     eax, 1
    jmp     .out
.switch:
    ; переключаем текстуру и звук
    call    P_ChangeSwitchTexture
    mov     rcx, [playermo]
    mov     edx, sfx_swtchn
    call    S_StartSound
    ; одноразовые линии
    cmp     esi, 62
    je      .keep
    cmp     esi, 60
    je      .keep
    cmp     esi, 63
    je      .keep
    mov     dword [lines + rbx + LN_SPECIAL], 0
.keep:
    mov     eax, 1
    jmp     .out
.fail:
    xor     eax, eax
.out:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; P_ShootSpecialLine(rcx = стрелок, edx = смещение линии)
P_ShootSpecialLine:
    push    rbx
    mov     ebx, edx
    mov     eax, [lines + rbx + LN_SPECIAL]
    cmp     eax, 24
    jne     .c46
    mov     ecx, [lines + rbx + LN_TAG]
    xor     edx, edx
    call    EV_DoFloor
    mov     dword [lines + rbx + LN_SPECIAL], 0
    jmp     .done
.c46:
    cmp     eax, 46
    jne     .done
    mov     ecx, [lines + rbx + LN_TAG]
    mov     edx, DT_OPEN
    mov     r8d, VDOORSPEED
    call    EV_DoDoor
    call    P_ChangeSwitchTexture
.done:
    pop     rbx
    ret

; P_ChangeSwitchTexture -- ebx = смещение линии
P_ChangeSwitchTexture:
    push    rsi
    mov     esi, [lines + rbx + LN_SIDE0]
    cmp     esi, -1
    je      .done
    imul    esi, SIDE_SIZE
    cmp     dword [sides + rsi + SD_MIDTEX], TEX_SWITCH1
    jne     .top
    mov     dword [sides + rsi + SD_MIDTEX], TEX_SWITCH2
    jmp     .done
.top:
    cmp     dword [sides + rsi + SD_TOPTEX], TEX_SWITCH1
    jne     .bot
    mov     dword [sides + rsi + SD_TOPTEX], TEX_SWITCH2
    jmp     .done
.bot:
    cmp     dword [sides + rsi + SD_BOTTEX], TEX_SWITCH1
    jne     .done
    mov     dword [sides + rsi + SD_BOTTEX], TEX_SWITCH2
.done:
    pop     rsi
    ret

; ---------------------------------------------------------------------------
;  EV_Teleport(rcx = mobj, edx = смещение линии)
; ---------------------------------------------------------------------------
EV_Teleport:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    mov     rbx, rcx
    mov     r12d, edx
    mov     ecx, [lines + r12 + LN_TAG]
    mov     edx, -1
    call    P_FindSectorFromTag
    cmp     eax, -1
    je      .done
    mov     esi, eax
    ; ищем точку назначения в секторе
    imul    eax, esi, SECTOR_SIZE
    mov     ecx, [sectors + rax + SEC_ORGX]
    mov     edx, [sectors + rax + SEC_ORGY]
    ; туман на старом месте
    push    rcx
    push    rdx
    mov     ecx, [rbx + MO_X]
    mov     edx, [rbx + MO_Y]
    mov     r8d, [rbx + MO_Z]
    mov     r9d, MT_TFOG
    call    P_SpawnMobj
    pop     rdx
    pop     rcx
    push    rcx
    push    rdx
    mov     rcx, rbx
    call    P_UnsetThingPosition
    pop     rdx
    pop     rcx
    mov     [rbx + MO_X], ecx
    mov     [rbx + MO_Y], edx
    mov     rcx, rbx
    call    P_SetThingPosition
    mov     rcx, rbx
    call    P_CalcFloorCeiling
    mov     eax, [rbx + MO_FLOORZ]
    mov     [rbx + MO_Z], eax
    mov     dword [rbx + MO_MOMX], 0
    mov     dword [rbx + MO_MOMY], 0
    mov     dword [rbx + MO_MOMZ], 0
    ; туман на новом месте
    mov     ecx, [rbx + MO_X]
    mov     edx, [rbx + MO_Y]
    mov     r8d, [rbx + MO_Z]
    mov     r9d, MT_TFOG
    call    P_SpawnMobj
    mov     rcx, rbx
    mov     edx, sfx_telept
    call    S_StartSound
    cmp     qword [rbx + MO_PLAYER], 0
    je      .done
    mov     dword [rbx + MO_REACTIONTIME], 18
.done:
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_PlayerInSpecialSector -- урон, секреты, выход
; ---------------------------------------------------------------------------
P_PlayerInSpecialSector:
    push    rbx
    push    rsi
    mov     rbx, [playermo]
    ; только стоя на полу
    mov     eax, [rbx + MO_Z]
    cmp     eax, [rbx + MO_FLOORZ]
    jne     .done
    mov     esi, [rbx + MO_SECTOR]
    imul    esi, SECTOR_SIZE
    mov     eax, [sectors + rsi + SEC_SPECIAL]
    cmp     eax, 5
    je      .dmg10
    cmp     eax, 7
    je      .dmg5
    cmp     eax, 16
    je      .dmg20
    cmp     eax, 4
    je      .dmg20
    cmp     eax, 9
    je      .secret
    cmp     eax, 11
    je      .endlevel
    jmp     .done
.dmg5:
    mov     edi, 5
    jmp     .dodamage
.dmg10:
    mov     edi, 10
    jmp     .dodamage
.dmg20:
    mov     edi, 20
.dodamage:
    cmp     dword [player + PL_POWERS + pw_ironfeet*4], 0
    jne     .radsuit
.applydmg:
    mov     eax, [leveltime]
    and     eax, 31
    jnz     .done
    mov     rcx, rbx
    xor     rdx, rdx
    xor     r8, r8
    mov     r9d, edi
    call    P_DamageMobj
    jmp     .done
.radsuit:
    call    P_Random
    cmp     eax, 5
    jge     .done
    jmp     .applydmg
.secret:
    inc     dword [player + PL_SECRETCOUNT]
    mov     dword [sectors + rsi + SEC_SPECIAL], 0
    mov     rcx, str_secret
    call    P_SetMessage
    jmp     .done
.endlevel:
    mov     eax, [leveltime]
    and     eax, 31
    jnz     .chkdeath
    mov     rcx, rbx
    xor     rdx, rdx
    xor     r8, r8
    mov     r9d, 20
    call    P_DamageMobj
.chkdeath:
    cmp     dword [player + PL_HEALTH], 11
    jge     .done
    mov     byte [g_exitlevel], 1
.done:
    pop     rsi
    pop     rbx
    ret

; P_SetMessage(rcx = строка)
P_SetMessage:
    mov     [player + PL_MESSAGE], rcx
    mov     dword [player + PL_MESSAGETICS], 4*35
    ret

; ---------------------------------------------------------------------------
;  P_UpdateSpecials -- тик всех механизмов и анимации
; ---------------------------------------------------------------------------
P_UpdateSpecials:
    push    rbx
    call    T_VerticalDoors
    call    T_Plats
    call    T_Floors
    call    T_MoveCeilings
    call    T_Lights
    ; анимация флэтов (кислота/кровь)
    mov     eax, [leveltime]
    shr     eax, 3
    and     eax, 3
    cmp     eax, 3
    jne     .anok
    mov     eax, 1
.anok:
    mov     ecx, eax
    add     ecx, FLAT_NUKAGE1
    mov     [flattranslation + FLAT_NUKAGE1*4], ecx
    mov     ecx, eax
    add     ecx, FLAT_BLOOD1
    mov     [flattranslation + FLAT_BLOOD1*4], ecx
    pop     rbx
    ret
