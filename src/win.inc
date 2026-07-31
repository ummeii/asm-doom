; ===========================================================================
;  win.inc -- константы Win32
; ===========================================================================

%define WS_OVERLAPPEDWINDOW 0x00cf0000
%define WS_VISIBLE          0x10000000
%define WS_POPUP            0x80000000
%define CW_USEDEFAULT       0x80000000

%define CS_VREDRAW          0x0001
%define CS_HREDRAW          0x0002
%define CS_OWNDC            0x0020

%define SW_SHOW             5
%define SW_SHOWNORMAL       1

%define PM_REMOVE           1

%define WM_DESTROY          0x0002
%define WM_SIZE             0x0005
%define WM_ACTIVATE         0x0006
%define WM_SETFOCUS         0x0007
%define WM_KILLFOCUS        0x0008
%define WM_PAINT            0x000f
%define WM_CLOSE            0x0010
%define WM_QUIT             0x0012
%define WM_ACTIVATEAPP      0x001c
%define WM_SETCURSOR        0x0020
%define WM_KEYDOWN          0x0100
%define WM_SYSKEYDOWN       0x0104
%define WM_SYSCOMMAND       0x0112

%define SC_KEYMENU          0xf100
%define SC_SCREENSAVE       0xf140
%define SC_MONITORPOWER     0xf170

%define IDC_ARROW           32512

%define SM_CXSCREEN         0
%define SM_CYSCREEN         1

%define DIB_RGB_COLORS      0
%define SRCCOPY             0x00cc0020
%define COLORONCOLOR        3

%define MEM_COMMIT          0x1000
%define MEM_RESERVE         0x2000
%define PAGE_READWRITE      0x04

%define GENERIC_WRITE       0x40000000
%define GENERIC_READ        0x80000000
%define CREATE_ALWAYS       2
%define OPEN_EXISTING       3
%define FILE_ATTRIBUTE_NORMAL 0x80

; ---- виртуальные коды клавиш ----
%define VK_LBUTTON  0x01
%define VK_RBUTTON  0x02
%define VK_MBUTTON  0x04
%define VK_BACK     0x08
%define VK_TAB      0x09
%define VK_RETURN   0x0d
%define VK_SHIFT    0x10
%define VK_CONTROL  0x11
%define VK_MENU     0x12
%define VK_ESCAPE   0x1b
%define VK_SPACE    0x20
%define VK_LEFT     0x25
%define VK_UP       0x26
%define VK_RIGHT    0x27
%define VK_DOWN     0x28
%define VK_F1       0x70
%define VK_F12      0x7b
%define VK_OEM_PLUS  0xbb
%define VK_OEM_MINUS 0xbd
%define VK_OEM_4    0xdb
%define VK_OEM_6    0xdd

; ---- индексы клавиш движка ----
%define K_RIGHT     0
%define K_LEFT      1
%define K_UP        2
%define K_DOWN      3
%define K_FORWARD   4
%define K_BACK      5
%define K_STRAFEL   6
%define K_STRAFER   7
%define K_FIRE      8
%define K_FIRE2     9
%define K_USE       10
%define K_USE2      11
%define K_RUN       12
%define K_STRAFE    13
%define K_STRAFE2   14
%define K_W1        15
%define K_W2        16
%define K_W3        17
%define K_W4        18
%define K_W5        19
%define K_W6        20
%define K_W7        21
%define K_MAP       22
%define K_ESC       23
%define K_ENTER     24
%define K_Y         25
%define K_N         26
%define K_SHOT      27
%define K_PLUS      28
%define K_MINUS     29
%define K_MOUSETOG  30
%define NUMKEYS     31
