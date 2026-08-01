; ===========================================================================
;  i_net.asm -- сеть: прямое соединение двух машин по UDP, без сервера
;
;  Обе стороны равноправны. За каждый тик каждая шлёт сопернику свою команду
;  и ждёт чужую; пока чужая не пришла, тик не считается -- иначе симуляции
;  разъедутся. Координаты по сети не гоняются: симуляция детерминированная,
;  из одинаковых команд обе машины получают одинаковый мир.
;
;  UDP теряет пакеты, а пропущенная команда -- это разошедшиеся миры, поэтому
;  в каждом пакете едет не одна команда, а последние NET_BACKCMDS. Потеря
;  подряд четырёх пакетов на локальной сети практически не встречается.
;
;      dd  'DOOM'          подпись, чтобы отсечь чужой трафик
;      dd  номер первого тика в пакете
;      dd  сколько команд следом
;      db  NET_BACKCMDS * 16 байт
;
;  Запуск: -net <адрес>  подключиться к соседу, -net  ждать подключения.
;  Номер игрока определяется тем, кто ждал: ждущий -- нулевой, пришедший --
;  первый.
; ===========================================================================

%define NET_PORT        5029
%define NET_HDR         12
%define NET_PKT         (NET_HDR + NET_BACKCMDS*TICCMD_SIZE)
%define AF_INET         2
%define SOCK_DGRAM      2
%define IPPROTO_UDP     17
%define FIONBIO         0x8004667E
%define INADDR_ANY      0

; ---------------------------------------------------------------------------
;  I_NetInit -> eax = 1, если сеть поднялась
; ---------------------------------------------------------------------------
I_NetInit:
    push    rbx
    FRAME
    cmp     byte [net_mode], 0
    je      .off

    CALLW   imp_WSAStartup, 0x0202, wsa_data
    test    eax, eax
    jnz     .fail

    CALLW   imp_socket, AF_INET, SOCK_DGRAM, IPPROTO_UDP
    cmp     rax, -1
    je      .fail
    mov     [net_sock], rax

    ; неблокирующий режим: ожиданием управляет главный цикл
    mov     dword [net_nb], 1
    CALLW   imp_ioctlsocket, [net_sock], FIONBIO, net_nb

    ; Порты разные у сторон, иначе две копии на одной машине не поднимутся:
    ; ждущий держит NET_PORT, пришедший -- соседний.
    mov     ecx, NET_PORT
    cmp     byte [net_mode], 2
    jne     .portok
    inc     ecx
.portok:
    mov     word [sa_local + 0], AF_INET
    CALLW   imp_htons, rcx
    mov     [sa_local + 2], ax
    mov     dword [sa_local + 4], INADDR_ANY
    CALLW   imp_bind, [net_sock], sa_local, 16
    test    eax, eax
    jnz     .fail

    ; адрес соперника
    mov     word [sa_peer + 0], AF_INET
    cmp     byte [net_mode], 2          ; 2 = подключаемся к указанному адресу
    jne     .listen
    mov     ecx, NET_PORT
    CALLW   imp_htons, rcx
    mov     [sa_peer + 2], ax
    CALLW   imp_inet_addr, net_addrstr
    mov     [sa_peer + 4], eax
    mov     dword [consoleplayer], 1    ; подключившийся -- первый
    jmp     .ok
.listen:
    mov     ecx, NET_PORT+1
    CALLW   imp_htons, rcx
    mov     [sa_peer + 2], ax
    mov     dword [sa_peer + 4], 0      ; адрес узнаем из первого пакета
    mov     dword [consoleplayer], 0
.ok:
    mov     dword [numplayers], 2
    mov     dword [net_active], 1
    mov     dword [net_peertic], -1
    mov     eax, 1
    jmp     .out
.fail:
    mov     byte [net_mode], 0
.off:
    mov     dword [net_active], 0
    xor     eax, eax
.out:
    ENDFRAME
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  I_NetSend -- отправить команду за тик d_maketic и несколько предыдущих
; ---------------------------------------------------------------------------
I_NetSend:
    push    rbx
    push    rsi
    push    rdi
    FRAME
    cmp     dword [net_active], 0
    je      .done
    cmp     dword [sa_peer + 4], 0      ; адрес соперника ещё не известен
    je      .done
    mov     dword [net_out + 0], NET_MAGIC
    mov     eax, [d_maketic]
    sub     eax, NET_BACKCMDS-1         ; самый старый тик в пакете
    mov     [net_out + 4], eax
    mov     dword [net_out + 8], NET_BACKCMDS
    xor     ebx, ebx
.pack:
    mov     edx, [net_out + 4]
    add     edx, ebx
    js      .zerocmd                    ; тиков до нулевого не было
    mov     ecx, [consoleplayer]
    call    D_CmdSlot
    mov     rsi, rax
    jmp     .copy
.zerocmd:
    lea     rsi, [zero_cmd]
.copy:
    imul    eax, ebx, TICCMD_SIZE
    lea     rdi, [net_out + NET_HDR]
    add     rdi, rax
    mov     ecx, TICCMD_SIZE
    rep     movsb
    inc     ebx
    cmp     ebx, NET_BACKCMDS
    jb      .pack
    CALLW   imp_sendto, [net_sock], net_out, NET_PKT, 0, sa_peer, 16
.done:
    ENDFRAME
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  I_NetPoll -- разобрать всё, что пришло; обновляет net_peertic
; ---------------------------------------------------------------------------
I_NetPoll:
    push    rbx
    push    rsi
    push    rdi
    push    r12
    FRAME
    cmp     dword [net_active], 0
    je      .done
.again:
    mov     dword [sa_from_len], 16
    CALLW   imp_recvfrom, [net_sock], net_in, NET_PKT, 0, sa_from, sa_from_len
    cmp     eax, NET_PKT
    jl      .done                       ; пусто или обрезок
    cmp     dword [net_in + 0], NET_MAGIC
    jne     .again                      ; чужой трафик -- пропускаем
    ; ждущая сторона узнаёт адрес и порт соперника из первого же пакета
    cmp     dword [sa_peer + 4], 0
    jne     .haveaddr
    mov     ax, [sa_from + 2]
    mov     [sa_peer + 2], ax
    mov     eax, [sa_from + 4]
    mov     [sa_peer + 4], eax
.haveaddr:
    mov     r12d, [net_in + 8]          ; сколько команд в пакете
    cmp     r12d, NET_BACKCMDS
    ja      .again
    xor     ebx, ebx
.unpack:
    cmp     ebx, r12d
    jae     .tail
    mov     edx, [net_in + 4]
    add     edx, ebx
    js      .nextcmd                    ; отрицательный тик -- заполнителя нет
    mov     ecx, [consoleplayer]
    xor     ecx, 1                      ; команда соперника
    call    D_CmdSlot
    mov     rdi, rax
    imul    eax, ebx, TICCMD_SIZE
    lea     rsi, [net_in + NET_HDR]
    add     rsi, rax
    mov     ecx, TICCMD_SIZE
    rep     movsb
.nextcmd:
    inc     ebx
    jmp     .unpack
.tail:
    mov     eax, [net_in + 4]
    add     eax, r12d
    dec     eax                         ; последний тик в пакете
    cmp     eax, [net_peertic]
    jle     .again
    mov     [net_peertic], eax
    jmp     .again
.done:
    ENDFRAME
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret

; ---------------------------------------------------------------------------
;  I_NetShutdown
; ---------------------------------------------------------------------------
I_NetShutdown:
    FRAME
    cmp     dword [net_active], 0
    je      .done
    CALLW   imp_closesocket, [net_sock]
    mov     dword [net_active], 0
.done:
    ENDFRAME
    ret
