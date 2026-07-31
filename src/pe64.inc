; ===========================================================================
;  pe64.inc -- заголовок PE32+ собранный вручную.
;  FileAlignment == SectionAlignment == 0x1000, поэтому RVA == смещение в файле.
;  Секции:  .text (RWX, код+данные+импорты),  .bss (nobits, через absolute)
; ===========================================================================

_base:
; --------------------------- DOS header ------------------------------------
    db      'MZ'
    times   0x3c-2 db 0
    dd      pe_sig - IMAGEBASE          ; e_lfanew

; --------------------------- PE signature ----------------------------------
pe_sig:
    db      'PE', 0, 0

; --------------------------- COFF header -----------------------------------
    dw      0x8664                      ; Machine = AMD64
    dw      2                           ; NumberOfSections
    dd      0                           ; TimeDateStamp
    dd      0                           ; PointerToSymbolTable
    dd      0                           ; NumberOfSymbols
    dw      opt_end - opt_start         ; SizeOfOptionalHeader
    dw      0x0022                      ; EXECUTABLE_IMAGE | LARGE_ADDRESS_AWARE

; --------------------------- Optional header (PE32+) -----------------------
opt_start:
    dw      0x020b                      ; magic PE32+
    db      14, 0                       ; linker version
    dd      text_end - text_start       ; SizeOfCode
    dd      0                           ; SizeOfInitializedData
    dd      0                           ; SizeOfUninitializedData
    dd      entry - IMAGEBASE           ; AddressOfEntryPoint
    dd      0x1000                      ; BaseOfCode
    dq      IMAGEBASE                   ; ImageBase
    dd      0x1000                      ; SectionAlignment
    dd      0x1000                      ; FileAlignment
    dw      6, 0                        ; OS version
    dw      0, 0                        ; Image version
    dw      6, 0                        ; Subsystem version
    dd      0                           ; Win32VersionValue
    dd      (BSS_RVA + (bss_end - bss_start) + 0xfff) & ~0xfff  ; SizeOfImage
    dd      0x1000                      ; SizeOfHeaders
    dd      0                           ; CheckSum
    dw      2                           ; Subsystem = WINDOWS_GUI
    dw      0                           ; DllCharacteristics
    dq      0x00200000                  ; SizeOfStackReserve (2 MB)
    dq      0x00010000                  ; SizeOfStackCommit
    dq      0x00100000                  ; SizeOfHeapReserve
    dq      0x00001000                  ; SizeOfHeapCommit
    dd      0                           ; LoaderFlags
    dd      16                          ; NumberOfRvaAndSizes
    dq      0                           ; [0] Export
    dd      import_desc - IMAGEBASE     ; [1] Import
    dd      import_desc_end - import_desc
    dq      0                           ; [2] Resource
    dq      0                           ; [3] Exception
    dq      0                           ; [4] Certificate
    dq      0                           ; [5] Relocation
    dq      0                           ; [6] Debug
    dq      0                           ; [7] Architecture
    dq      0                           ; [8] Global ptr
    dq      0                           ; [9] TLS
    dq      0                           ; [10] Load config
    dq      0                           ; [11] Bound import
    dd      iat_start - IMAGEBASE       ; [12] IAT
    dd      iat_end - iat_start
    dq      0                           ; [13] Delay import
    dq      0                           ; [14] COM descriptor
    dq      0                           ; [15] reserved
opt_end:

; --------------------------- Section headers -------------------------------
    db      '.text', 0, 0, 0
    dd      BSS_RVA - 0x1000            ; VirtualSize (до начала .bss)
    dd      text_start - IMAGEBASE      ; VirtualAddress
    dd      text_end - text_start       ; SizeOfRawData
    dd      text_start - IMAGEBASE      ; PointerToRawData
    dd      0, 0
    dw      0, 0
    dd      0xe0000060                  ; CODE|EXECUTE|READ|WRITE

    db      '.bss', 0, 0, 0, 0
    dd      bss_end - bss_start         ; VirtualSize
    dd      BSS_RVA                     ; VirtualAddress
    dd      0                           ; SizeOfRawData
    dd      0                           ; PointerToRawData
    dd      0, 0
    dw      0, 0
    dd      0xc0000080                  ; UNINITIALIZED_DATA|READ|WRITE

    times   0x1000 - ($ - _base) db 0
text_start:
