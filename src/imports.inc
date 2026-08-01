; ===========================================================================
;  imports.inc -- таблица импортов PE, собранная вручную.
;  Списки функций описаны один раз и разворачиваются трижды:
;    THUNKL -- IAT (с метками imp_XXX, через них идут вызовы)
;    THUNKU -- ILT (копия без меток)
;    NAMEDEF -- hint/name таблица
; ===========================================================================

%macro THUNKL 1
    imp_%1: dq hint_%1 - IMAGEBASE
%endmacro

%macro THUNKU 1
    dq      hint_%1 - IMAGEBASE
%endmacro

%macro NAMEDEF 1
    %defstr _NAMESTR %1
    hint_%1:
    dw      0
    db      _NAMESTR, 0
    align   2
    %undef _NAMESTR
%endmacro

%macro LIST_KERNEL32 1
    %1 ExitProcess
    %1 GetModuleHandleA
    %1 QueryPerformanceCounter
    %1 QueryPerformanceFrequency
    %1 Sleep
    %1 VirtualAlloc
    %1 GetCommandLineA
    %1 CreateFileA
    %1 WriteFile
    %1 ReadFile
    %1 CloseHandle
    %1 GetTickCount
    %1 OutputDebugStringA
%endmacro

%macro LIST_USER32 1
    %1 RegisterClassExA
    %1 CreateWindowExA
    %1 DestroyWindow
    %1 DefWindowProcA
    %1 PeekMessageA
    %1 TranslateMessage
    %1 DispatchMessageA
    %1 PostQuitMessage
    %1 ShowWindow
    %1 UpdateWindow
    %1 GetDC
    %1 ReleaseDC
    %1 GetClientRect
    %1 GetWindowRect
    %1 GetAsyncKeyState
    %1 GetCursorPos
    %1 SetCursorPos
    %1 ShowCursor
    %1 ClientToScreen
    %1 MessageBoxA
    %1 AdjustWindowRect
    %1 GetSystemMetrics
    %1 SetForegroundWindow
    %1 GetForegroundWindow
    %1 LoadCursorA
    %1 SetWindowPos
%endmacro

%macro LIST_GDI32 1
    %1 StretchDIBits
    %1 SetStretchBltMode
%endmacro

%macro LIST_WINMM 1
    %1 waveOutOpen
    %1 waveOutPrepareHeader
    %1 waveOutWrite
    %1 waveOutUnprepareHeader
    %1 waveOutReset
    %1 waveOutClose
    %1 timeBeginPeriod
%endmacro

%macro LIST_WS2 1
    %1 WSAStartup
    %1 socket
    %1 bind
    %1 sendto
    %1 recvfrom
    %1 ioctlsocket
    %1 closesocket
    %1 inet_addr
    %1 htons
%endmacro

; ------------------------------ дескрипторы --------------------------------
    align   8
import_desc:
    dd      ilt_kernel32 - IMAGEBASE
    dd      0, 0
    dd      name_kernel32 - IMAGEBASE
    dd      iat_kernel32 - IMAGEBASE

    dd      ilt_user32 - IMAGEBASE
    dd      0, 0
    dd      name_user32 - IMAGEBASE
    dd      iat_user32 - IMAGEBASE

    dd      ilt_gdi32 - IMAGEBASE
    dd      0, 0
    dd      name_gdi32 - IMAGEBASE
    dd      iat_gdi32 - IMAGEBASE

    dd      ilt_winmm - IMAGEBASE
    dd      0, 0
    dd      name_winmm - IMAGEBASE
    dd      iat_winmm - IMAGEBASE

    dd      ilt_ws2 - IMAGEBASE
    dd      0, 0
    dd      name_ws2 - IMAGEBASE
    dd      iat_ws2 - IMAGEBASE

    dd      0, 0, 0, 0, 0               ; терминатор
import_desc_end:

; ------------------------------ IAT ----------------------------------------
    align   8
iat_start:
iat_kernel32:
    LIST_KERNEL32 THUNKL
    dq      0
iat_user32:
    LIST_USER32 THUNKL
    dq      0
iat_gdi32:
    LIST_GDI32 THUNKL
    dq      0
iat_winmm:
    LIST_WINMM THUNKL
    dq      0
iat_ws2:
    LIST_WS2 THUNKL
    dq      0
iat_end:

; ------------------------------ ILT ----------------------------------------
    align   8
ilt_kernel32:
    LIST_KERNEL32 THUNKU
    dq      0
ilt_user32:
    LIST_USER32 THUNKU
    dq      0
ilt_gdi32:
    LIST_GDI32 THUNKU
    dq      0
ilt_winmm:
    LIST_WINMM THUNKU
    dq      0
ilt_ws2:
    LIST_WS2 THUNKU
    dq      0

; ------------------------------ имена --------------------------------------
    align   2
    LIST_KERNEL32 NAMEDEF
    LIST_USER32 NAMEDEF
    LIST_GDI32 NAMEDEF
    LIST_WINMM NAMEDEF
    LIST_WS2 NAMEDEF

name_kernel32:  db 'KERNEL32.dll', 0
    align   2
name_user32:    db 'USER32.dll', 0
    align   2
name_gdi32:     db 'GDI32.dll', 0
    align   2
name_winmm:     db 'WINMM.dll', 0
    align   2
name_ws2:       db 'WS2_32.dll', 0
    align   2
