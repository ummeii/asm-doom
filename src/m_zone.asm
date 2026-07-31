; ===========================================================================
;  m_zone.asm -- простейший аллокатор: один большой блок + указатель-бампер
; ===========================================================================

%define ZONESIZE (64*1024*1024)

Z_Init:
    FRAME
    CALLW   imp_VirtualAlloc, 0, ZONESIZE, MEM_COMMIT|MEM_RESERVE, PAGE_READWRITE
    mov     [g_zone], rax
    test    rax, rax
    jnz     .ok
    mov     rcx, str_err_mem
    call    I_Error
.ok:
    mov     qword [g_zonepos], 0
    ENDFRAME
    ret

; Z_Malloc(rcx = размер) -> rax (выровнено на 16, обнулено)
Z_Malloc:
    add     rcx, 15
    and     rcx, -16
    mov     rax, [g_zone]
    add     rax, [g_zonepos]
    add     [g_zonepos], rcx
    mov     rdx, [g_zonepos]
    cmp     rdx, ZONESIZE
    jb      .ok
    mov     rcx, str_err_mem
    call    I_Error
.ok:
    ret
