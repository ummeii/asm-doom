; ===========================================================================
;  data.inc -- инициализированные данные (строки, таблицы кодов клавиш)
; ===========================================================================

    align 8
str_class:      db 'DOOMASM', 0
str_title:      db 'DOOM (x86-64 assembly)', 0
str_errfile:    db 'error.txt', 0
str_logfile:    db 'doom.log', 0
str_shotfile:   db 'shot.bmp', 0
str_err_wnd:    db 'CreateWindowEx failed', 0
str_err_mem:    db 'out of memory', 0
str_err_map:    db 'bad map record', 0

; --------------------------- константы с плавающей точкой -------------------
    align 8
f_8192:     dd 8192.0
f_65536:    dd 65536.0
f_4096:     dd 4096.0
f_2048:     dd 2048.0
f_2047h:    dd 2047.5
f_ang180:   dd 2147483648.0
    align 16
f_intmin:   dq -2147483000.0
f_intmax:   dq 2147483000.0

; --------------------------- рампы палитры ---------------------------------
;  start, count, r0,g0,b0, r1,g1,b1   (от яркого к тёмному)
    align 8
pal_ramps:
    db 1,   31,  255,255,255,   12,12,12         ; серый
    db 32,  32,  235,199,151,   43,27,15         ; коричневый
    db 64,  32,  255,0,0,       31,0,0           ; красный
    db 96,  32,  119,255,111,   0,27,0           ; зелёный
    db 128, 32,  140,140,255,   0,0,40           ; синий
    db 160, 16,  255,255,80,    40,40,0          ; жёлтый
    db 176, 16,  255,160,32,    40,16,0          ; оранжевый
    db 192, 16,  255,219,187,   47,27,19         ; телесный
    db 208, 16,  0,255,255,     0,40,48          ; бирюзовый
    db 224, 16,  255,100,255,   40,0,48          ; фиолетовый
    db 240, 16,  255,235,190,   60,50,35         ; светлый загар

; --------------------------- звуки ------------------------------------------
; тип, частота/8, длительность/64 отсчётов, параметр
    align 8
sfxdefs:
    db SND_NOISE, 0,   0,  0     ; 0  нет звука
    db SND_NOISE, 0,   12, 0     ; 1  пистолет
    db SND_NOISE, 0,   20, 1     ; 2  дробовик
    db SND_CLICK, 0,   4,  0     ; 3  затвор
    db SND_TONE,  50,  8,  0     ; 4  плазма
    db SND_SWEEP, 12,  30, 200   ; 5  BFG
    db SND_TONE,  60,  10, 0     ; 6  пила заводится
    db SND_TONE,  40,  6,  0     ; 7  пила вхолостую
    db SND_TONE,  90,  8,  0     ; 8  пила
    db SND_NOISE, 0,   6,  0     ; 9  пила попала
    db SND_NOISE, 0,   16, 1     ; 10 пуск ракеты
    db SND_NOISE, 0,   40, 1     ; 11 взрыв ракеты
    db SND_SWEEP, 30,  10, 100   ; 12 огненный шар
    db SND_NOISE, 0,   24, 1     ; 13 взрыв шара
    db SND_TONE,  25,  10, 0     ; 14 лифт пошёл
    db SND_TONE,  20,  6,  0     ; 15 лифт встал
    db SND_SWEEP, 12,  24, 60    ; 16 дверь открывается
    db SND_TONE,  16,  20, 0     ; 17 дверь закрывается
    db SND_NOISE, 0,   30, 1     ; 18 движение пола
    db SND_CLICK, 0,   6,  0     ; 19 переключатель
    db SND_CLICK, 0,   6,  0     ; 20 переключатель обратно
    db SND_GROWL, 30,  14, 0     ; 21 боль игрока
    db SND_GROWL, 20,  16, 0     ; 22 боль демона
    db SND_GROWL, 35,  12, 0     ; 23 боль зомби
    db SND_NOISE, 0,   14, 1     ; 24 хлюп
    db SND_TONE,  110, 6,  0     ; 25 подобрал предмет
    db SND_TONE,  90,  8,  0     ; 26 подобрал оружие
    db SND_NOISE, 0,   8,  1     ; 27 удар о пол
    db SND_SWEEP, 20,  26, 220   ; 28 телепорт
    db SND_GROWL, 28,  20, 0     ; 29 зомби заметил
    db SND_GROWL, 22,  22, 0     ; 30 имп заметил
    db SND_GROWL, 16,  24, 0     ; 31 демон заметил
    db SND_GROWL, 12,  28, 0     ; 32 барон заметил
    db SND_GROWL, 18,  26, 0     ; 33 какодемон заметил
    db SND_TONE,  70,  8,  0     ; 34 атака черепа
    db SND_GROWL, 26,  10, 0     ; 35 атака демона
    db SND_NOISE, 0,   8,  0     ; 36 когти
    db SND_GROWL, 24,  30, 0     ; 37 смерть игрока
    db SND_GROWL, 30,  24, 0     ; 38 смерть зомби
    db SND_GROWL, 26,  26, 0     ; 39 смерть импа
    db SND_GROWL, 18,  28, 0     ; 40 смерть демона
    db SND_GROWL, 14,  30, 0     ; 41 смерть какодемона
    db SND_GROWL, 10,  34, 0     ; 42 смерть барона
    db SND_GROWL, 34,  10, 0     ; 43 зомби ворчит
    db SND_GROWL, 30,  12, 0     ; 44 имп ворчит
    db SND_GROWL, 24,  12, 0     ; 45 демон ворчит
    db SND_TONE,  30,  5,  0     ; 46 не открывается
    db SND_NOISE, 0,   44, 1     ; 47 взрыв бочки
    db SND_NOISE, 0,   6,  0     ; 48 удар кулаком
    db SND_SWEEP, 34,  10, 90    ; 49 атака импа
    db SND_SWEEP, 60,  16, 180   ; 50 усиление

; --------------------------- игровые таблицы --------------------------------
    align 8
action_table:
    dq A_NULL_f, A_Look_f, A_Chase_f, A_FaceTarget_f, A_PosAttack_f
    dq A_SPosAttack_f, A_TroopAttack_f, A_SargAttack_f, A_HeadAttack_f
    dq A_BruisAttack_f, A_SkullAttack_f, A_Scream_f, A_XScream_f, A_Pain_f
    dq A_Fall_f, A_Explode_f, A_BossDeath_f, A_WeaponReady_f, A_Lower_f
    dq A_Raise_f, A_Punch_f, A_ReFire_f, A_FirePistol_f, A_FireShotgun_f
    dq A_FireCGun_f, A_FireMissile_f, A_FirePlasma_f, A_FireBFG_f
    dq A_BFGSpray_f, A_Light0_f, A_Light1_f, A_Light2_f, A_GunFlash_f
    dq A_CheckReload_f, A_Saw_f, A_PlayerScream_f, A_NULL_f

    align 8
weaponinfo:
    dd am_noammo, S_PUNCHUP, S_PUNCHDOWN, S_PUNCH, S_PUNCH1, S_NULL
    dd am_clip, S_PISTOLUP, S_PISTOLDOWN, S_PISTOL, S_PISTOL1, S_PISTOLFLASH
    dd am_shell, S_SGUNUP, S_SGUNDOWN, S_SGUN, S_SGUN1, S_SGUNFLASH
    dd am_clip, S_CHAINUP, S_CHAINDOWN, S_CHAIN, S_CHAIN1, S_CHAINFLASH
    dd am_misl, S_MISSILEUP, S_MISSILEDOWN, S_MISSILE, S_MISSILE1, S_MISSILEFLASH
    dd am_cell, S_PLASMAUP, S_PLASMADOWN, S_PLASMA, S_PLASMA1, S_PLASMAFLASH
    dd am_cell, S_BFGUP, S_BFGDOWN, S_BFG, S_BFG1, S_BFGFLASH
    dd am_noammo, S_SAWUP, S_SAWDOWN, S_SAW, S_SAW1, S_NULL
    dd am_shell, S_SGUNUP, S_SGUNDOWN, S_SGUN, S_SGUN1, S_SGUNFLASH

    align 8
clipammo:       dd 10, 4, 20, 1
maxammostart:   dd 200, 50, 300, 50
weaponkey:      dd wp_fist, wp_pistol, wp_shotgun, wp_chaingun, wp_missile, wp_plasma, wp_bfg
forwardmovetab: dd 0x19, 0x32
sidemovetab:    dd 0x18, 0x28
angleturn:      dd 640, 1280
legphase:       dd 0, 2, 0, -2
xspeed:         dd FRACUNIT, 47000, 0, -47000, -FRACUNIT, -47000, 0, 47000
yspeed:         dd 0, 47000, FRACUNIT, 47000, 0, -47000, -FRACUNIT, -47000
diags:          dd 3, 1, 5, 7      ; NW, NE, SW, SE

; спрайт, цвет тела, цвет головы, высота, ширина, стиль
creaturedefs:
    db SPR_PLAY, PAL_GREEN,  PAL_FLESH,  56, 28, 0, 0, 0
    db SPR_POSS, PAL_BROWN,  PAL_FLESH,  52, 26, 0, 0, 0
    db SPR_SPOS, PAL_BLUE,   PAL_FLESH,  52, 26, 0, 0, 0
    db SPR_TROO, PAL_ORANGE, PAL_BROWN,  54, 28, 0, 0, 0
    db SPR_SARG, PAL_FLESH,  PAL_RED,    50, 44, 1, 0, 0
    db SPR_HEAD, PAL_RED,    PAL_GRAY,   52, 48, 2, 0, 0
    db SPR_BOSS, PAL_TEAL,   PAL_GREEN,  70, 36, 0, 0, 0
    db SPR_SKUL, PAL_GRAY,   PAL_ORANGE, 24, 22, 2, 0, 0
    db 255, 0,0,0,0,0,0,0

; спрайт, цвет, форма (0 шар, 1 коробка, 2 плоский), размер, кадров
itemdefs:
    db SPR_BON1, PAL_BLUE,   0, 10, 4, 0,0,0
    db SPR_BON2, PAL_GREEN,  0, 10, 4, 0,0,0
    db SPR_SOUL, PAL_BLUE,   0, 18, 4, 0,0,0
    db SPR_PINV, PAL_PURPLE, 0, 16, 4, 0,0,0
    db SPR_PSTR, PAL_RED,    0, 16, 4, 0,0,0
    db SPR_PINS, PAL_TEAL,   0, 16, 4, 0,0,0
    db SPR_BKEY, PAL_BLUE,   2, 14, 4, 0,0,0
    db SPR_YKEY, PAL_YELLOW, 2, 14, 4, 0,0,0
    db SPR_RKEY, PAL_RED,    2, 14, 4, 0,0,0
    db SPR_STIM, PAL_GRAY,   1, 12, 1, 0,0,0
    db SPR_MEDI, PAL_TAN,    1, 16, 1, 0,0,0
    db SPR_ARM1, PAL_GREEN,  1, 18, 1, 0,0,0
    db SPR_ARM2, PAL_BLUE,   1, 18, 1, 0,0,0
    db SPR_CLIP, PAL_GRAY,   1, 8,  1, 0,0,0
    db SPR_AMMO, PAL_BROWN,  1, 14, 1, 0,0,0
    db SPR_SHEL, PAL_RED,    1, 8,  1, 0,0,0
    db SPR_SBOX, PAL_RED,    1, 14, 1, 0,0,0
    db SPR_ROCK, PAL_GRAY,   1, 10, 1, 0,0,0
    db SPR_BROK, PAL_GRAY,   1, 16, 1, 0,0,0
    db SPR_CELL, PAL_YELLOW, 1, 10, 1, 0,0,0
    db SPR_CELP, PAL_YELLOW, 1, 16, 1, 0,0,0
    db SPR_BPAK, PAL_BROWN,  1, 16, 1, 0,0,0
    db SPR_SHOT, PAL_BROWN,  1, 12, 1, 0,0,0
    db SPR_MGUN, PAL_GRAY,   1, 12, 1, 0,0,0
    db SPR_LAUN, PAL_GREEN,  1, 14, 1, 0,0,0
    db SPR_PLAS, PAL_BLUE,   1, 14, 1, 0,0,0
    db SPR_BFUG, PAL_GREEN,  1, 16, 1, 0,0,0
    db SPR_CSAW, PAL_GRAY,   1, 12, 1, 0,0,0
    db SPR_SUIT, PAL_GREEN,  1, 20, 1, 0,0,0
    db SPR_PMAP, PAL_TEAL,   2, 16, 1, 0,0,0
    db SPR_PVIS, PAL_YELLOW, 0, 14, 1, 0,0,0
    db SPR_COLU, PAL_TAN,    1, 26, 1, 0,0,0
    db SPR_BAR1, PAL_GREEN,  1, 22, 2, 0,0,0
    db 255, 0,0,0,0,0,0,0

; спрайт, цвет, радиус, кадров
effectdefs:
    db SPR_BAL1, PAL_ORANGE, 5,  5
    db SPR_BAL7, PAL_GREEN,  6,  5
    db SPR_MISL, PAL_GRAY,   4,  1
    db SPR_PLSS, PAL_BLUE,   5,  5
    db SPR_BFS1, PAL_GREEN,  10, 5
    db SPR_PUFF, PAL_GRAY,   3,  4
    db SPR_BLUD, PAL_RED,    4,  3
    db SPR_TFOG, PAL_TEAL,   8,  4
    db SPR_BEXP, PAL_ORANGE, 12, 3
    db 255, 0, 0, 0

; отдача ствола по кадрам (сдвиг по Y)
weaprecoil: db 0, -6, -3, 0

; формы оружия: спрайт, затем x0,y0,x1,y1,цвет ... 255 -- конец оружия
weapshapes:
    db SPR_PUNG                             ; кулак
    db 54, 88, 74,127, PAL_FLESH+7          ; предплечье
    db 48, 66, 78, 94, PAL_FLESH+3          ; кулак
    db 52, 70, 58, 78, PAL_FLESH+9          ; костяшки
    db 60, 70, 66, 78, PAL_FLESH+9
    db 255
    db SPR_PISG                             ; пистолет
    db 42, 98, 60,127, PAL_FLESH+6          ; рука
    db 44, 84, 58,110, PAL_GRAY+16          ; рукоять
    db 40, 72, 62, 90, PAL_GRAY+11          ; корпус
    db 38, 68, 64, 76, PAL_GRAY+7           ; затвор
    db 46, 52, 54, 70, PAL_GRAY+14          ; ствол
    db 255
    db SPR_SHTG                             ; дробовик
    db 40,100, 62,127, PAL_FLESH+6          ; рука
    db 42, 86, 60,112, PAL_BROWN+10         ; приклад
    db 36, 68, 64, 90, PAL_GRAY+12          ; ствольная коробка
    db 40, 56, 60, 68, PAL_BROWN+6          ; цевьё
    db 44, 24, 56, 60, PAL_GRAY+15          ; ствол
    db 46, 20, 54, 26, PAL_GRAY+9           ; дульный срез
    db 255
    db SPR_CHGG                             ; пулемёт
    db 36,100, 66,127, PAL_FLESH+6
    db 34, 74, 68,104, PAL_GRAY+12
    db 38, 66, 64, 76, PAL_GRAY+8
    db 40, 36, 46, 70, PAL_GRAY+16          ; стволы
    db 48, 32, 54, 70, PAL_GRAY+13
    db 56, 36, 62, 70, PAL_GRAY+16
    db 255
    db SPR_MISG                             ; ракетница
    db 34,104, 68,127, PAL_FLESH+6
    db 30, 62, 72,106, PAL_GREEN+12
    db 34, 54, 68, 64, PAL_GREEN+8
    db 26, 40, 76, 56, PAL_GREEN+16         ; раструб
    db 36, 36, 64, 44, PAL_GRAY+22          ; жерло
    db 255
    db SPR_PLSG                             ; плазмаган
    db 36,102, 66,127, PAL_FLESH+6
    db 32, 68, 70,106, PAL_BLUE+12
    db 38, 58, 64, 70, PAL_BLUE+7
    db 44, 44, 58, 60, PAL_BLUE+3           ; излучатель
    db 48, 40, 54, 48, PAL_TEAL+2
    db 255
    db SPR_BFGG                             ; BFG
    db 34,104, 68,127, PAL_FLESH+6
    db 28, 64, 74,108, PAL_GREEN+14
    db 32, 56, 70, 66, PAL_GREEN+9
    db 36, 40, 66, 58, PAL_GREEN+5          ; раструб
    db 44, 34, 58, 44, PAL_GREEN+1
    db 255
    db SPR_SAWG                             ; бензопила
    db 44, 96, 66,127, PAL_BROWN+8
    db 36, 72, 70,100, PAL_GRAY+13
    db 30, 56, 76, 74, PAL_GRAY+9           ; шина
    db 32, 50, 74, 58, PAL_GRAY+5           ; зубья
    db 255
    db 255

    align 8
; шрифт 4x6: бит 0 -- левый пиксель
fontdata:
    db 6,9,9,9,9,6      ; 0
    db 2,6,2,2,2,7      ; 1
    db 6,9,8,6,1,15     ; 2
    db 6,9,12,8,9,6     ; 3
    db 8,12,10,15,8,8   ; 4
    db 15,1,7,8,9,6     ; 5
    db 6,1,7,9,9,6      ; 6
    db 15,8,4,4,2,2     ; 7
    db 6,9,6,9,9,6      ; 8
    db 6,9,9,14,8,6     ; 9
    db 6,9,9,15,9,9     ; A
    db 7,9,7,9,9,7      ; B
    db 6,9,1,1,9,6      ; C
    db 7,9,9,9,9,7      ; D
    db 15,1,7,1,1,15    ; E
    db 15,1,7,1,1,1     ; F
    db 6,1,13,9,9,6     ; G
    db 9,9,15,9,9,9     ; H
    db 7,2,2,2,2,7      ; I
    db 8,8,8,8,9,6      ; J
    db 9,5,3,3,5,9      ; K
    db 1,1,1,1,1,15     ; L
    db 9,15,15,9,9,9    ; M
    db 9,11,15,13,9,9   ; N
    db 6,9,9,9,9,6      ; O
    db 7,9,7,1,1,1      ; P
    db 6,9,9,9,5,10     ; Q
    db 7,9,7,5,9,9      ; R
    db 14,1,6,8,9,6     ; S
    db 15,2,2,2,2,2     ; T
    db 9,9,9,9,9,6      ; U
    db 9,9,9,9,6,6      ; V
    db 9,9,9,15,15,9    ; W
    db 9,9,6,6,9,9      ; X
    db 9,9,6,2,2,2      ; Y
    db 15,8,4,2,1,15    ; Z

    align 8
am_arrow:                       ; x0,y0,x1,y1 в пикселях
    db -8, 0,  8, 0
    db  8, 0,  2, -4
    db  8, 0,  2, 4

    align 8
skillnames:
    dq str_sk1, str_sk2, str_sk3, str_sk4, str_sk5
str_sk1:    db '1 TOO YOUNG TO DIE', 0
str_sk2:    db '2 HEY NOT TOO ROUGH', 0
str_sk3:    db '3 HURT ME PLENTY', 0
str_sk4:    db '4 ULTRA VIOLENCE', 0
str_sk5:    db '5 NIGHTMARE', 0
str_title1: db 'DOOM', 0
str_title2: db 'X86-64 ASSEMBLY', 0
str_cursor: db '>', 0
str_help1:  db 'ENTER  START GAME', 0
str_help2:  db 'TAB MAP   M MOUSE   ESC MENU', 0

    align 8
keycolors:      dd PAL_BLUE+2, PAL_YELLOW+2, PAL_RED+2
str_hp:         db 'HP', 0
str_arm:        db 'ARM', 0
str_ammo:       db 'AMMO', 0
str_kills:      db 'KILL', 0

    align 8
str_needblue:   db 'You need a blue key', 0
str_needyellow: db 'You need a yellow key', 0
str_needred:    db 'You need a red key', 0
str_secret:     db 'A secret is revealed!', 0

; --------------------------- генераторы текстур -----------------------------
    align 8
texgen_table:
    dq TG_Panel, TG_Brick, TG_Door, TG_Noise, TG_Switch, TG_Comp, TG_Sky, TG_Step
flatgen_table:
    dq FG_Tile, FG_Noise, FG_Grate

; ширина/8, высота, узор, базовый цвет, длина рампы, параметр, 2 байта запаса
texdefs:
    db 8,  64,  0, PAL_GRAY,  31, 0, 0,0        ; 0  нет текстуры
    db 8,  128, 0, PAL_GRAY,  31, 0, 0,0        ; 1  TEK1
    db 8,  128, 1, PAL_BROWN, 32, 0, 0,0        ; 2  BROWN
    db 8,  128, 0, PAL_TAN,   16, 0, 0,0        ; 3  STARTAN
    db 4,  128, 2, PAL_GRAY+16,15,0, 0,0        ; 4  DOORTRAK
    db 8,  128, 2, PAL_GRAY,  31, 0, 0,0        ; 5  BIGDOOR
    db 8,  128, 4, PAL_TAN,   16, 0, 0,0        ; 6  SWITCH выкл
    db 8,  128, 4, PAL_TAN,   16, 1, 0,0        ; 7  SWITCH вкл
    db 8,  128, 5, PAL_GRAY,  31, 0, 0,0        ; 8  COMP
    db 8,  128, 2, PAL_GRAY,  31, PAL_BLUE, 0,0 ; 9  дверь синяя
    db 8,  128, 2, PAL_GRAY,  31, PAL_YELLOW,0,0; 10 дверь жёлтая
    db 8,  128, 2, PAL_GRAY,  31, PAL_RED, 0,0  ; 11 дверь красная
    db 8,  128, 2, PAL_BROWN, 32, PAL_GREEN,0,0 ; 12 выход
    db 8,  128, 1, PAL_GRAY,  31, 0, 0,0        ; 13 GSTONE
    db 8,  128, 3, PAL_GRAY,  31, 0, 0,0        ; 14 MARBLE
    db 4,  128, 0, PAL_BROWN, 32, 0, 0,0        ; 15 SUPPORT
    db 8,  128, 0, PAL_TAN,   16, 0, 0,0        ; 16 LITE
    db 8,  128, 3, PAL_GRAY,  24, 0, 0,0        ; 17 METAL
    db 8,  16,  7, PAL_BROWN, 32, 0, 0,0        ; 18 STEP
    db 8,  128, 3, PAL_RED,   32, 0, 0,0        ; 19 BLOODWALL
    db 32, 128, 6, 0,         0,  0, 0,0        ; 20 небо

; узор, базовый цвет, длина рампы, параметр
flatdefs:
    db 0, PAL_GRAY,    31, 0                    ; 0  плитка пола
    db 1, PAL_BROWN,   32, 0                    ; 1  бурый
    db 1, PAL_GRAY+12, 19, 0                    ; 2  потолок
    db 1, PAL_GREEN,   32, 0                    ; 3  кислота 1
    db 1, PAL_GREEN,   32, 3                    ; 4  кислота 2
    db 1, PAL_GREEN,   32, 6                    ; 5  кислота 3
    db 1, PAL_RED,     32, 0                    ; 6  кровь 1
    db 1, PAL_RED,     32, 3                    ; 7  кровь 2
    db 1, PAL_RED,     32, 6                    ; 8  кровь 3
    db 2, PAL_GRAY,    31, 0                    ; 9  решётка
    db 0, PAL_TAN,     16, 0                    ; 10 светлый
    db 0, PAL_BROWN,   32, 0                    ; 11 ступень
    db 1, PAL_BLUE,    32, 0                    ; 12 небо (не рисуется)
    db 1, PAL_RED+8,   20, 0                    ; 13 ковёр
    db 1, PAL_BROWN+4, 24, 0                    ; 14 камень

    align 8
fuzzoffset:
    db 2,0,2,2,0,2,2,2,0,2,2,0,2,0,2,2,0,2,2,2,0,0,0,2,0,2
    db 2,0,0,2,2,0,2,2,0,0,2,0,0,2,2,0,2,0,2,2,0,0,2,0

    align 8
; виртуальные коды для индексов K_*
vk_table:
    db VK_RIGHT             ; K_RIGHT
    db VK_LEFT              ; K_LEFT
    db VK_UP                ; K_UP
    db VK_DOWN              ; K_DOWN
    db 'W'                  ; K_FORWARD
    db 'S'                  ; K_BACK
    db 'A'                  ; K_STRAFEL
    db 'D'                  ; K_STRAFER
    db VK_CONTROL           ; K_FIRE
    db VK_LBUTTON           ; K_FIRE2
    db VK_SPACE             ; K_USE
    db 'E'                  ; K_USE2
    db VK_SHIFT             ; K_RUN
    db VK_MENU              ; K_STRAFE
    db VK_RBUTTON           ; K_STRAFE2
    db '1'                  ; K_W1
    db '2'                  ; K_W2
    db '3'                  ; K_W3
    db '4'                  ; K_W4
    db '5'                  ; K_W5
    db '6'                  ; K_W6
    db '7'                  ; K_W7
    db VK_TAB               ; K_MAP
    db VK_ESCAPE            ; K_ESC
    db VK_RETURN            ; K_ENTER
    db 'Y'                  ; K_Y
    db 'N'                  ; K_N
    db VK_F12               ; K_SHOT
    db VK_OEM_PLUS          ; K_PLUS
    db VK_OEM_MINUS         ; K_MINUS
    db 'M'                  ; K_MOUSETOG

    align 8
keyarts:
    dq art_keyb
    dq art_keyy
    dq art_keyr

str_finished:   db 'LEVEL     FINISHED', 0
str_items:      db 'ITEMS', 0
str_wisecret:   db 'SECRET', 0
str_wikills:    db 'KILLS', 0
str_time:       db 'TIME', 0
str_press:      db 'PRESS FIRE TO CONTINUE', 0

    align 8
wi_labels:
    dq str_wikills
    dq str_items
    dq str_wisecret

    align 8
; приращения фазы: частота ноты * 65536 / 11025
mus_bass:
    dd 487, 487, 487, 487, 487, 487, 517, 487, 487, 487, 487, 487, 487, 487, 517, 487
    dd 487, 487, 487, 487, 487, 487, 583, 547, 487, 487, 487, 487, 487, 487, 517, 487
    dd 434, 434, 434, 434, 434, 434, 464, 434, 434, 434, 434, 434, 434, 434, 487, 517
    dd 487, 487, 487, 487, 487, 487, 517, 487, 487, 487, 695, 695, 487, 487, 517, 547
mus_lead:
    dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    dd 1385, 0, 981, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    dd 0, 0, 0, 0, 0, 0, 0, 0, 1468, 0, 1385, 0, 0, 0, 0, 0
    dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    dd 1962, 0, 1385, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    dd 0, 0, 0, 0, 0, 0, 0, 0, 2075, 1962, 0, 0, 0, 0, 0, 0
    dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    dd 1385, 1468, 1385, 981, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
; третий голос -- бас, расстроенный на 1.2%, даёт грязь и биение
mus_pad:
    dd 493, 493, 493, 493, 493, 493, 523, 493, 493, 493, 493, 493, 493, 493, 523, 493
    dd 493, 493, 493, 493, 493, 493, 590, 553, 493, 493, 493, 493, 493, 493, 523, 493
    dd 439, 439, 439, 439, 439, 439, 469, 439, 439, 439, 439, 439, 439, 439, 493, 523
    dd 493, 493, 493, 493, 493, 493, 523, 493, 493, 493, 704, 704, 493, 493, 523, 553

; подписи полей строки состояния
str_lammo:      db 'AMMO', 0
str_lhealth:    db 'HEALTH', 0
str_larms:      db 'ARMS', 0
str_lfrags:     db 'FRAGS', 0
str_larmor:     db 'ARMOR', 0
str_abull:      db 'BULL', 0
str_ashel:      db 'SHEL', 0
str_arckt:      db 'RCKT', 0
str_acell:      db 'CELL', 0

    align 8
st_ammolabels:
    dq str_abull
    dq str_ashel
    dq str_arckt
    dq str_acell
