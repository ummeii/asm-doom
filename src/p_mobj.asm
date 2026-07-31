; ===========================================================================
;  p_mobj.asm -- пул объектов, привязка к секторам и блокам
; ===========================================================================

; ---------------------------------------------------------------------------
;  P_InitMobjs
; ---------------------------------------------------------------------------
P_InitMobjs:
    push    rbx
    xor     ebx, ebx
.l: mov     eax, ebx
    imul    eax, MOBJ_SIZE
    lea     rdx, [mobjs]
    add     rdx, rax
    mov     dword [rdx + MO_INUSE], 0
    inc     ebx
    cmp     ebx, MAXMOBJS
    jb      .l
    mov     dword [nummobjs], 0
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_NewMobj -> rax (или 0)
; ---------------------------------------------------------------------------
P_NewMobj:
    push    rbx
    xor     ebx, ebx
.l: mov     eax, ebx
    imul    eax, MOBJ_SIZE
    lea     rdx, [mobjs]
    add     rdx, rax
    cmp     dword [rdx + MO_INUSE], 0
    je      .found
    inc     ebx
    cmp     ebx, MAXMOBJS
    jb      .l
    xor     eax, eax
    pop     rbx
    ret
.found:
    ; очистка
    mov     rax, rdx
    push    rdi
    mov     rdi, rdx
    mov     ecx, MOBJ_SIZE/8
    push    rax
    xor     eax, eax
.clr:
    mov     [rdi], rax
    add     rdi, 8
    dec     ecx
    jnz     .clr
    pop     rax
    pop     rdi
    mov     dword [rax + MO_INUSE], 1
    inc     dword [nummobjs]
    cmp     ebx, [maxmobjused]
    jbe     .nomax
    mov     [maxmobjused], ebx
.nomax:
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_UnsetThingPosition(rcx = mobj) -- снять со списков сектора и блока
; ---------------------------------------------------------------------------
P_UnsetThingPosition:
    push    rbx
    mov     rbx, rcx
    test    dword [rbx + MO_FLAGS], MF_NOSECTOR
    jnz     .noSector
    mov     rax, [rbx + MO_SPREV]
    mov     rdx, [rbx + MO_SNEXT]
    test    rax, rax
    jz      .headsec
    mov     [rax + MO_SNEXT], rdx
    jmp     .fixnext
.headsec:
    mov     eax, [rbx + MO_SECTOR]
    cmp     eax, -1
    je      .fixnext
    imul    eax, SECTOR_SIZE
    mov     [sectors + rax + SEC_THINGLIST], rdx
.fixnext:
    test    rdx, rdx
    jz      .noSector
    mov     rax, [rbx + MO_SPREV]
    mov     [rdx + MO_SPREV], rax
.noSector:
    test    dword [rbx + MO_FLAGS], MF_NOBLOCKMAP
    jnz     .done
    mov     rax, [rbx + MO_BPREV]
    mov     rdx, [rbx + MO_BNEXT]
    test    rax, rax
    jz      .headblk
    mov     [rax + MO_BNEXT], rdx
    jmp     .fixbnext
.headblk:
    mov     eax, [rbx + MO_BLOCKY]
    cmp     eax, -1
    je      .fixbnext
    imul    eax, [bmapwidth]
    add     eax, [rbx + MO_BLOCKX]
    mov     [blocklinks + rax*8], rdx
.fixbnext:
    test    rdx, rdx
    jz      .done
    mov     rax, [rbx + MO_BPREV]
    mov     [rdx + MO_BPREV], rax
.done:
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_SetThingPosition(rcx = mobj)
; ---------------------------------------------------------------------------
P_SetThingPosition:
    push    rbx
    push    rsi
    push    rdi
    mov     rbx, rcx
    ; сектор
    mov     ecx, [rbx + MO_X]
    mov     edx, [rbx + MO_Y]
    call    R_PointInSector
    mov     [rbx + MO_SECTOR], eax
    test    dword [rbx + MO_FLAGS], MF_NOSECTOR
    jnz     .noSector
    cmp     eax, -1
    je      .noSector
    imul    eax, SECTOR_SIZE
    mov     rdx, [sectors + rax + SEC_THINGLIST]
    mov     qword [rbx + MO_SPREV], 0
    mov     [rbx + MO_SNEXT], rdx
    test    rdx, rdx
    jz      .nosnext
    mov     [rdx + MO_SPREV], rbx
.nosnext:
    mov     [sectors + rax + SEC_THINGLIST], rbx
.noSector:
    ; блок
    mov     dword [rbx + MO_BLOCKX], -1
    mov     dword [rbx + MO_BLOCKY], -1
    test    dword [rbx + MO_FLAGS], MF_NOBLOCKMAP
    jnz     .done
    mov     eax, [rbx + MO_X]
    sub     eax, [bmaporgx]
    sar     eax, MAPBLOCKSHIFT
    mov     esi, eax
    mov     eax, [rbx + MO_Y]
    sub     eax, [bmaporgy]
    sar     eax, MAPBLOCKSHIFT
    mov     edi, eax
    test    esi, esi
    js      .done
    test    edi, edi
    js      .done
    cmp     esi, [bmapwidth]
    jge     .done
    cmp     edi, [bmapheight]
    jge     .done
    mov     [rbx + MO_BLOCKX], esi
    mov     [rbx + MO_BLOCKY], edi
    mov     eax, edi
    imul    eax, [bmapwidth]
    add     eax, esi
    mov     rdx, [blocklinks + rax*8]
    mov     qword [rbx + MO_BPREV], 0
    mov     [rbx + MO_BNEXT], rdx
    test    rdx, rdx
    jz      .nobnext
    mov     [rdx + MO_BPREV], rbx
.nobnext:
    mov     [blocklinks + rax*8], rbx
.done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_SpawnMobj(ecx=x, edx=y, r8d=z, r9d=тип) -> rax
;    z = ONFLOORZ (MININT) -> на пол, ONCEILINGZ (MAXINT) -> к потолку
; ---------------------------------------------------------------------------
%define ONFLOORZ    MININT
%define ONCEILINGZ  MAXINT

P_SpawnMobj:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    mov     r12d, ecx
    mov     r13d, edx
    mov     r14d, r8d
    mov     esi, r9d                    ; тип
    call    P_NewMobj
    test    rax, rax
    jnz     .ok
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
.ok:
    mov     rbx, rax
    mov     [rbx + MO_X], r12d
    mov     [rbx + MO_Y], r13d
    mov     [rbx + MO_TYPE], esi
    ; параметры типа
    imul    eax, esi, MOBJINFO_SIZE
    lea     rdi, [mobjinfo]
    add     rdi, rax
    mov     [rbx + MO_INFO], rdi
    mov     eax, [rdi + MI_RADIUS]
    mov     [rbx + MO_RADIUS], eax
    mov     eax, [rdi + MI_HEIGHT]
    mov     [rbx + MO_HEIGHT], eax
    mov     eax, [rdi + MI_FLAGS]
    mov     [rbx + MO_FLAGS], eax
    mov     eax, [rdi + MI_SPAWNHEALTH]
    mov     [rbx + MO_HEALTH], eax
    mov     eax, [rdi + MI_REACTIONTIME]
    mov     [rbx + MO_REACTIONTIME], eax
    mov     dword [rbx + MO_LASTLOOK], 0
    ; состояние
    mov     ecx, [rdi + MI_SPAWNSTATE]
    imul    eax, ecx, STATE_SIZE
    lea     rdx, [states]
    add     rdx, rax
    mov     [rbx + MO_STATE], rdx
    mov     eax, [rdx + ST_TICS]
    mov     [rbx + MO_TICS], eax
    mov     eax, [rdx + ST_SPRITE]
    mov     [rbx + MO_SPRITE], eax
    mov     eax, [rdx + ST_FRAME]
    mov     [rbx + MO_FRAME], eax
    ; позиция
    mov     rcx, rbx
    call    P_SetThingPosition
    ; высоты пола/потолка
    mov     rcx, rbx
    call    P_CalcFloorCeiling
    cmp     r14d, ONFLOORZ
    jne     .notfloor
    mov     eax, [rbx + MO_FLOORZ]
    mov     [rbx + MO_Z], eax
    jmp     .zdone
.notfloor:
    cmp     r14d, ONCEILINGZ
    jne     .absz
    mov     eax, [rbx + MO_CEILINGZ]
    sub     eax, [rbx + MO_HEIGHT]
    mov     [rbx + MO_Z], eax
    jmp     .zdone
.absz:
    mov     [rbx + MO_Z], r14d
.zdone:
    mov     rax, rbx
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  P_CalcFloorCeiling(rcx = mobj) -- по сектору под объектом
; ---------------------------------------------------------------------------
P_CalcFloorCeiling:
    mov     eax, [rcx + MO_SECTOR]
    cmp     eax, -1
    jne     .ok
    mov     dword [rcx + MO_FLOORZ], 0
    mov     dword [rcx + MO_CEILINGZ], 128*FRACUNIT
    ret
.ok:
    imul    eax, SECTOR_SIZE
    mov     edx, [sectors + rax + SEC_FLOORH]
    mov     [rcx + MO_FLOORZ], edx
    mov     [rcx + MO_DROPOFFZ], edx
    mov     edx, [sectors + rax + SEC_CEILH]
    mov     [rcx + MO_CEILINGZ], edx
    ret

; ---------------------------------------------------------------------------
;  P_RemoveMobj(rcx = mobj)
; ---------------------------------------------------------------------------
P_RemoveMobj:
    push    rbx
    mov     rbx, rcx
    call    P_UnsetThingPosition
    mov     dword [rbx + MO_INUSE], 0
    dec     dword [nummobjs]
    pop     rbx
    ret
