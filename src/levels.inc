; ===========================================================================
;  levels.inc -- данные уровней
;
;  Вершины сектора перечисляются по часовой стрелке (ось Y вверх).
;  Общее ребро двух секторов автоматически становится двусторонней линией.
; ===========================================================================

%macro MV 2                             ; вершина
    dd 3, %1, %2
%endmacro

%macro MSEC 7                           ; пол, потолок, флэт пола, флэт потолка,
    dd 1, %1, %2, %3, %4, %5, %6, %7    ; свет, спецэффект, тег
%endmacro

%macro MW 10                            ; v1,v2,верх,серед,низ,xoff,yoff,флаги,спец,тег
    dd 2, %1, %2, %3, %4, %5, %6, %7, %8, %9, %{10}
%endmacro

%macro MWS 3                            ; простая сплошная стена: v1,v2,текстура
    dd 2, %1, %2, 0, %3, 0, 0, 0, ML_BLOCKING, 0, 0
%endmacro

%macro MWP 5                            ; портал: v1,v2,верхняя,нижняя,флаги
    dd 2, %1, %2, %3, 0, %4, 0, 0, %5, 0, 0
%endmacro

%macro MTH 5                            ; x, y, угол(град), тип, флаги
    dd 4, %1, %2, %3, %4, %5
%endmacro

%macro MEND 0
    dd 0
%endmacro

; ===========================================================================
;  Уровень 1
; ===========================================================================
    align 8
level1:
; --- вершины ---
    MV 0,    0          ; 0
    MV 0,    1024        ; 1
    MV 1024,  1024        ; 2
    MV 1024,  576        ; 3
    MV 1024,  448        ; 4
    MV 1024,  0          ; 5
    MV 1536,  448        ; 6
    MV 1536,  576        ; 7
    MV 1536,  0          ; 8
    MV 1536,  1024        ; 9
    MV 2560, 1024        ; 10
    MV 2560, 0          ; 11
    MV 1472,  448        ; 12
    MV 1472,  576        ; 13

; --- сектор 0: стартовый зал ---
    MSEC 0, 128, FLAT_FLOOR, FLAT_CEIL, 192, 0, 0
    MWS 0, 1, TEX_TEK1
    MWS 1, 2, TEX_TEK1
    MWS 2, 3, TEX_TEK1
    MWP 3, 4, TEX_TEK1, TEX_STEP, 0
    MWS 4, 5, TEX_TEK1
    MWS 5, 0, TEX_TEK1

; --- сектор 1: коридор ---
    MSEC 16, 96, FLAT_STEP, FLAT_CEIL, 144, 0, 0
    MWP 4, 3, TEX_TEK1, TEX_STEP, 0
    MWS 3, 13, TEX_BROWN
    ; линия двери: спец 1 = открыть-подождать-закрыть по нажатию
    MW 13, 12, TEX_BIGDOOR, 0, TEX_STEP, 0, 0, 0, 1, 0
    MWS 12, 4, TEX_BROWN

; --- сектор 2: большой зал с небом ---
    MSEC 32, 256, FLAT_BROWN, FLAT_SKY, 255, 0, 0
    MWS 8, 6, TEX_GSTONE
    MW 6, 7, TEX_BIGDOOR, 0, TEX_STEP, 0, 0, 0, 1, 0
    MWS 7, 9, TEX_GSTONE
    MWS 9, 10, TEX_GSTONE
    ; переключатель выхода с уровня (спец 11 = S1 exit)
    MW 10, 11, 0, TEX_SWITCH1, 0, 0, 0, ML_BLOCKING, 11, 0
    MWS 11, 8, TEX_GSTONE

; --- сектор 3: сама дверь (потолок опущен до пола) ---
    MSEC 16, 16, FLAT_STEP, FLAT_CEIL, 144, 0, 0
    MWP 12, 13, TEX_BIGDOOR, TEX_STEP, 0
    MWS 13, 7, TEX_DOORTRAK
    MWP 7, 6, TEX_BIGDOOR, TEX_STEP, 0
    MWS 6, 12, TEX_DOORTRAK

; --- объекты ---
    MTH 512, 512, 0, 1, 7               ; старт игрока
    MTH 1800, 512, 180, 3004, 7          ; зомби
    MTH 2200, 800, 180, 3001, 7         ; имп
    MTH 2200, 240, 180, 9, 7            ; сержант
    MTH 1280, 512, 0, 2007, 7            ; обойма
    MTH 1800, 800, 0, 2011, 7            ; аптечка
    MTH 1800, 240, 0, 2018, 7            ; броня
    MTH 2400, 512, 0, 2001, 7           ; дробовик
    MTH 800, 800, 0, 2035, 7            ; бочка
    MTH 900, 512, 180, 3004, 7|MTF_AMBUSH          ; зомби в стартовом зале
    MEND

; ===========================================================================
;  Уровень 2 -- лифт, синяя дверь с ключом, телепорт
;
;  Маршрут: старт -> коридор (пересечение портала опускает лифт, спец 88)
;           -> лифт (тег 1) -> зал с ключом и небом -> синяя дверь (спец 26)
;           -> камера -> линия телепорта (спец 97) -> зал выхода (тег 2).
; ===========================================================================
    align 8
level2:
; --- вершины ---
    MV 0,    0          ; 0
    MV 0,    512        ; 1
    MV 640,  512        ; 2
    MV 640,  384        ; 3
    MV 640,  128         ; 4
    MV 640,  0          ; 5
    MV 1152,  384        ; 6
    MV 1152,  128         ; 7
    MV 1408,  384        ; 8
    MV 1408,  128         ; 9
    MV 1408,  0          ; 10
    MV 1408,  512        ; 11
    MV 2432, 512        ; 12
    MV 2432, 320        ; 13
    MV 2432, 192         ; 14
    MV 2432, 0          ; 15
    MV 2560, 320        ; 16
    MV 2560, 192         ; 17
    MV 2752, 320        ; 18
    MV 2752, 192         ; 19
    MV 2944, 320        ; 20
    MV 2944, 192         ; 21
    MV 0,    1024        ; 22
    MV 0,    1536        ; 23
    MV 768,  1536        ; 24
    MV 768,  1024        ; 25

; --- сектор 0: стартовый зал ---
    MSEC 0, 128, FLAT_FLOOR, FLAT_CEIL, 176, 0, 0
    MWS 0, 1, TEX_TEK1
    MWS 1, 2, TEX_TEK1
    MWS 2, 3, TEX_TEK1
    ; выход в коридор -- он же спусковой крючок лифта (спец 88 = WR опустить)
    MW 3, 4, TEX_TEK1, 0, TEX_STEP, 0, 0, 0, 88, 1
    MWS 4, 5, TEX_TEK1
    MWS 5, 0, TEX_TEK1

; --- сектор 1: коридор ---
    MSEC 0, 96, FLAT_STEP, FLAT_CEIL, 128, 0, 0
    MWP 4, 3, TEX_TEK1, TEX_STEP, 0
    MWS 3, 6, TEX_BROWN
    MWP 6, 7, TEX_METAL, TEX_SUPPORT, 0
    MWS 7, 4, TEX_BROWN

; --- сектор 2: лифт (тег 1) ---
    MSEC 64, 192, FLAT_STEP, FLAT_LIGHT, 192, 0, 1
    MWP 7, 6, TEX_METAL, TEX_SUPPORT, 0
    MWS 6, 8, TEX_METAL
    MWP 8, 9, TEX_METAL, TEX_SUPPORT, 0
    MWS 9, 7, TEX_METAL

; --- сектор 3: верхний зал с небом ---
    MSEC 64, 320, FLAT_BROWN, FLAT_SKY, 255, 0, 0
    MWS 10, 9, TEX_GSTONE
    MWP 9, 8, TEX_GSTONE, TEX_SUPPORT, 0
    MWS 8, 11, TEX_GSTONE
    MWS 11, 12, TEX_GSTONE
    MWS 12, 13, TEX_GSTONE
    ; синяя дверь: спец 26 = DR, нужен синий ключ
    MW 13, 14, TEX_DOORBLU, 0, TEX_STEP, 0, 0, 0, 26, 0
    MWS 14, 15, TEX_GSTONE
    MWS 15, 10, TEX_GSTONE

; --- сектор 4: створка синей двери ---
    MSEC 64, 64, FLAT_STEP, FLAT_CEIL, 144, 0, 0
    MWP 14, 13, TEX_DOORBLU, TEX_STEP, 0
    MWS 13, 16, TEX_DOORTRAK
    MWP 16, 17, TEX_DOORBLU, TEX_STEP, 0
    MWS 17, 14, TEX_DOORTRAK

; --- сектор 5: камера перед телепортом ---
    MSEC 64, 160, FLAT_ROCK, FLAT_CEIL, 160, 0, 0
    MWP 17, 16, TEX_DOORBLU, TEX_STEP, 0
    MWS 16, 18, TEX_MARBLE
    ; линия телепорта: спец 97 = WR, цель -- сектор с тегом 2
    MW 18, 19, TEX_MARBLE, 0, TEX_STEP, 0, 0, 0, 97, 2
    MWS 19, 17, TEX_MARBLE

; --- сектор 6: площадка телепорта ---
    MSEC 64, 160, FLAT_ROCK, FLAT_LIGHT, 208, 12, 0
    MWP 19, 18, TEX_MARBLE, TEX_STEP, 0
    MWS 18, 20, TEX_MARBLE
    MWS 20, 21, TEX_COMP
    MWS 21, 19, TEX_MARBLE

; --- сектор 7: зал выхода, попасть можно только телепортом (тег 2) ---
    MSEC 0, 160, FLAT_CARPET, FLAT_CEIL, 192, 0, 2
    MWS 22, 23, TEX_MARBLE
    MWS 23, 24, TEX_MARBLE
    MW 24, 25, 0, TEX_SWITCH1, 0, 0, 0, ML_BLOCKING, 11, 0
    MWS 25, 22, TEX_MARBLE

; --- объекты ---
    MTH 320,  256, 0,   1,    7     ; старт игрока
    MTH 896,  256, 0,   2007, 7     ; обойма в коридоре
    MTH 1520,  256, 0,   2001, 7     ; дробовик сразу за лифтом
    MTH 1700,  420, 180, 3004, 7     ; зомби
    MTH 1700,  92,  180, 9,    7     ; сержант
    MTH 1900,  256, 0,   5,    7     ; синий ключ
    MTH 2000, 440, 0,   2018, 7     ; броня
    MTH 2100, 256, 0,   2012, 7     ; аптечка
    MTH 2240, 92,  180, 3001, 7     ; имп
    MTH 1560,  60,  0,   2035, 7     ; бочка
    MTH 2300, 256, 180, 3001, MTF_HARD              ; имп только на «ультра»
    MTH 1800,  256, 180, 3004, MTF_NORMAL|MTF_HARD   ; зомби с «средней»
    MTH 2320, 420, 0,   2049, MTF_EASY              ; лишние патроны новичку
    MTH 2848, 256, 180, 2008, 7     ; патроны на площадке телепорта
    MTH 600,  1400, 180, 3002, 7     ; демон у выхода
    MTH 200,  1200, 0,   2019, 7     ; тяжёлая броня у выхода
    MEND

; ===========================================================================
;  Уровень 3 -- лестница и давящий потолок
;
;  Маршрут: старт -> (спец 25 запускает пресс в нише) -> коридор
;           -> (спец 8 строит лестницу, тег 1) -> четыре ступени -> уступ
;           с переключателем выхода.
; ===========================================================================
    align 8
level3:
; --- вершины ---
    MV 0,   0           ; 0
    MV 0,   512         ; 1
    MV 512, 512         ; 2
    MV 512, 320         ; 3
    MV 512, 192          ; 4
    MV 512, 0           ; 5
    MV 896, 320         ; 6
    MV 896, 192          ; 7
    MV 1024, 320         ; 8
    MV 1024, 192          ; 9
    MV 1152, 320         ; 10
    MV 1152, 192          ; 11
    MV 1280, 320         ; 12
    MV 1280, 192          ; 13
    MV 1408, 320         ; 14
    MV 1408, 192          ; 15
    MV 1408, 0           ; 16
    MV 1408, 512         ; 17
    MV 1920, 512         ; 18
    MV 1920, 0           ; 19
    MV 896, 512         ; 20
    MV 576, 320         ; 21
    MV 576, 512         ; 22

; --- сектор 0: стартовый зал ---
    MSEC 0, 128, FLAT_FLOOR, FLAT_CEIL, 176, 0, 0
    MWS 0, 1, TEX_STARTAN
    MWS 1, 2, TEX_STARTAN
    MWS 2, 3, TEX_STARTAN
    ; выход в коридор запускает пресс в нише (спец 25 = W1 давить и поднять)
    MW 3, 4, TEX_STARTAN, 0, TEX_STEP, 0, 0, 0, 25, 2
    MWS 4, 5, TEX_STARTAN
    MWS 5, 0, TEX_STARTAN

; --- сектор 1: коридор с окном в нишу ---
    MSEC 0, 128, FLAT_STEP, FLAT_CEIL, 160, 0, 0
    MWP 4, 3, TEX_STARTAN, TEX_STEP, 0
    MWS 3, 21, TEX_METAL
    MWP 21, 6, TEX_METAL, TEX_STEP, 0
    ; вход на лестницу строит её (спец 8 = W1 лестница по 8 единиц, тег 1)
    MW 6, 7, TEX_METAL, 0, TEX_STEP, 0, 0, 0, 8, 1
    MWS 7, 4, TEX_METAL

; --- сектор 2: ниша с прессом (тег 2), пол разъедает ---
    MSEC 0, 128, FLAT_NUKAGE1, FLAT_CEIL, 128, 7, 2
    MWS 21, 22, TEX_BLOODWALL
    MWS 22, 20, TEX_BLOODWALL
    MWS 20, 6, TEX_BLOODWALL
    MWP 6, 21, TEX_METAL, TEX_STEP, 0

; --- секторы 3..6: ступени, тег 1 на первой ---
    MSEC 0, 128, FLAT_STEP, FLAT_CEIL, 144, 0, 1
    MWP 7, 6, TEX_METAL, TEX_STEP, 0
    MWS 6, 8, TEX_SUPPORT
    MWP 8, 9, TEX_SUPPORT, TEX_STEP, 0
    MWS 9, 7, TEX_SUPPORT

    MSEC 0, 128, FLAT_STEP, FLAT_CEIL, 152, 0, 0
    MWP 9, 8, TEX_SUPPORT, TEX_STEP, 0
    MWS 8, 10, TEX_SUPPORT
    MWP 10, 11, TEX_SUPPORT, TEX_STEP, 0
    MWS 11, 9, TEX_SUPPORT

    MSEC 0, 128, FLAT_STEP, FLAT_CEIL, 160, 0, 0
    MWP 11, 10, TEX_SUPPORT, TEX_STEP, 0
    MWS 10, 12, TEX_SUPPORT
    MWP 12, 13, TEX_SUPPORT, TEX_STEP, 0
    MWS 13, 11, TEX_SUPPORT

    MSEC 0, 128, FLAT_STEP, FLAT_CEIL, 168, 0, 0
    MWP 13, 12, TEX_SUPPORT, TEX_STEP, 0
    MWS 12, 14, TEX_SUPPORT
    MWP 14, 15, TEX_SUPPORT, TEX_STEP, 0
    MWS 15, 13, TEX_SUPPORT

; --- сектор 7: верхний уступ с выходом ---
    MSEC 40, 168, FLAT_CARPET, FLAT_LIGHT, 224, 0, 0
    MWS 16, 15, TEX_MARBLE
    MWP 15, 14, TEX_MARBLE, TEX_STEP, 0
    MWS 14, 17, TEX_MARBLE
    MWS 17, 18, TEX_MARBLE
    MW 18, 19, 0, TEX_SWITCH1, 0, 0, 0, ML_BLOCKING, 11, 0
    MWS 19, 16, TEX_MARBLE

; --- объекты ---
    MTH 256, 256, 0,   1,    7      ; старт игрока
    MTH 700, 400, 270, 3004, 7      ; зомби под прессом
    MTH 700, 440, 0,   2018, 7      ; броня в нише
    MTH 400, 256, 0,   2001, 7      ; дробовик у старта
    MTH 1600, 256, 180, 3001, 7      ; имп на уступе
    MTH 1760, 120,  0,   2012, 7      ; аптечка
    MTH 1760, 400, 0,   2008, 7      ; патроны
    MEND

    align 8
levellist:
    dq level1
    dq level2
    dq level3
