; ===========================================================================
;  defs.inc -- структуры карты, объектов и игрока (смещения полей)
; ===========================================================================

%define FUZZTABLE 50
%define NUMLEVELS 4
%define FF_FULLBRIGHT 0x8000
%define AM_ARROWSEG 3
%define USERANGE     (64*FRACUNIT)
%define MELEERANGE   (64*FRACUNIT)
%define MISSILERANGE (32*64*FRACUNIT)
%define VIEWHEIGHT   (41*FRACUNIT)
%define BT_ATTACK   1
%define BT_USE      2
%define BT_CHANGE   4
%define WI_AMMO         0
%define WI_UPSTATE      4
%define WI_DOWNSTATE    8
%define WI_READYSTATE   12
%define WI_ATKSTATE     16
%define WI_FLASHSTATE   20
%define WI_SIZE         24

; --------------------------- пределы ---------------------------------------
%define MAXVERTEXES 2048
%define MAXSECTORS  512
%define MAXSIDES    2048
%define MAXLINES    2048
%define MAXWALLDEFS 2048
%define MAXMOBJS    2048
%define MAXTHINKERS 512

; --------------------------- vertex_t --------------------------------------
%define VX_X        0
%define VX_Y        4
%define VERTEX_SIZE 8

; --------------------------- sector_t --------------------------------------
%define SEC_FLOORH      0
%define SEC_CEILH       4
%define SEC_FLOORPIC    8
%define SEC_CEILPIC     12
%define SEC_LIGHT       16
%define SEC_SPECIAL     20
%define SEC_TAG         24
%define SEC_LINECOUNT   28
%define SEC_LINES       32      ; dq -> массив индексов линий
%define SEC_THINGLIST   40      ; dq -> первый mobj сектора
%define SEC_SPECIALDATA 48      ; dq -> активный механизм (дверь/лифт)
%define SEC_SOUNDTARGET 56      ; dq -> mobj
%define SEC_VALIDCOUNT  64
%define SEC_SOUNDTRAV   68
%define SEC_BBOXTOP     72
%define SEC_BBOXBOT     76
%define SEC_BBOXLEFT    80
%define SEC_BBOXRIGHT   84
%define SEC_ORGX        88
%define SEC_ORGY        92
%define SEC_OLDFLOORH   96
%define SEC_OLDCEILH    100
%define SEC_LIGHTBASE   104
%define SEC_PAD         108
%define SECTOR_SIZE     112

; --------------------------- side_t ----------------------------------------
%define SD_TEXOFF   0
%define SD_ROWOFF   4
%define SD_TOPTEX   8
%define SD_BOTTEX   12
%define SD_MIDTEX   16
%define SD_SECTOR   20
%define SIDE_SIZE   24

; --------------------------- line_t ----------------------------------------
%define LN_V1       0
%define LN_V2       4
%define LN_DX       8
%define LN_DY       12
%define LN_FLAGS    16
%define LN_SPECIAL  20
%define LN_TAG      24
%define LN_SIDE0    28
%define LN_SIDE1    32
%define LN_FRONTSEC 36
%define LN_BACKSEC  40
%define LN_SLOPETYPE 44
%define LN_VALID    48
%define LN_BBOXTOP  52
%define LN_BBOXBOT  56
%define LN_BBOXLEFT 60
%define LN_BBOXRIGHT 64
%define LN_PAD      68
%define LINE_SIZE   72

; --- флаги линий (как в DOOM) ---
%define ML_BLOCKING         1
%define ML_BLOCKMONSTERS    2
%define ML_TWOSIDED         4
%define ML_DONTPEGTOP       8
%define ML_DONTPEGBOTTOM    16
%define ML_SECRET           32
%define ML_SOUNDBLOCK       64
%define ML_DONTDRAW         128
%define ML_MAPPED           256

; --- типы наклона линии ---
%define ST_HORIZONTAL 0
%define ST_VERTICAL   1
%define ST_POSITIVE   2
%define ST_NEGATIVE   3

; --------------------------- mobj_t ----------------------------------------
%define MO_X            0
%define MO_Y            4
%define MO_Z            8
%define MO_ANGLE        12
%define MO_MOMX         16
%define MO_MOMY         20
%define MO_MOMZ         24
%define MO_TYPE         28
%define MO_INFO         32      ; dq
%define MO_STATE        40      ; dq
%define MO_TICS         48
%define MO_FLAGS        52
%define MO_HEALTH       56
%define MO_RADIUS       60
%define MO_HEIGHT       64
%define MO_MOVEDIR      68
%define MO_MOVECOUNT    72
%define MO_REACTIONTIME 76
%define MO_THRESHOLD    80
%define MO_SECTOR       84
%define MO_FLOORZ       88
%define MO_CEILINGZ     92
%define MO_SNEXT        96      ; dq  список сектора
%define MO_SPREV        104
%define MO_BNEXT        112     ; dq  список блока
%define MO_BPREV        120
%define MO_TARGET       128     ; dq
%define MO_TRACER       136     ; dq
%define MO_PLAYER       144     ; dq
%define MO_SPRITE       152
%define MO_FRAME        156
%define MO_SPAWNX       160
%define MO_SPAWNY       164
%define MO_SPAWNANG     168
%define MO_SPAWNTYPE    172
%define MO_LASTLOOK     176
%define MO_VALID        180
%define MO_INUSE        184
%define MO_BLOCKX       188
%define MO_BLOCKY       192
%define MO_DROPOFFZ     196
%define MO_PAD          200
%define MOBJ_SIZE       208

; --- флаги mobj (как в DOOM) ---
%define MF_SPECIAL      0x0001
%define MF_SOLID        0x0002
%define MF_SHOOTABLE    0x0004
%define MF_NOSECTOR     0x0008
%define MF_NOBLOCKMAP   0x0010
%define MF_AMBUSH       0x0020
%define MF_JUSTHIT      0x0040
%define MF_JUSTATTACKED 0x0080
%define MF_SPAWNCEILING 0x0100
%define MF_NOGRAVITY    0x0200
%define MF_DROPOFF      0x0400
%define MF_PICKUP       0x0800
%define MF_NOCLIP       0x1000
%define MF_SLIDE        0x2000
%define MF_FLOAT        0x4000
%define MF_TELEPORT     0x8000
%define MF_MISSILE      0x10000
%define MF_DROPPED      0x20000
%define MF_SHADOW       0x40000
%define MF_NOBLOOD      0x80000
%define MF_CORPSE       0x100000
%define MF_INFLOAT      0x200000
%define MF_COUNTKILL    0x400000
%define MF_COUNTITEM    0x800000
%define MF_SKULLFLY     0x1000000
%define MF_NOTDMATCH    0x2000000

; --------------------------- state_t ---------------------------------------
%define ST_SPRITE   0
%define ST_FRAME    4
%define ST_TICS     8
%define ST_ACTION   12      ; индекс действия
%define ST_NEXT     16
%define ST_MISC1    20
%define ST_MISC2    24
%define ST_PAD      28
%define STATE_SIZE  32

; --------------------------- mobjinfo_t ------------------------------------
%define MI_DOOMEDNUM    0
%define MI_SPAWNSTATE   4
%define MI_SPAWNHEALTH  8
%define MI_SEESTATE     12
%define MI_SEESOUND     16
%define MI_REACTIONTIME 20
%define MI_ATTACKSOUND  24
%define MI_PAINSTATE    28
%define MI_PAINCHANCE   32
%define MI_PAINSOUND    36
%define MI_MELEESTATE   40
%define MI_MISSILESTATE 44
%define MI_DEATHSTATE   48
%define MI_XDEATHSTATE  52
%define MI_DEATHSOUND   56
%define MI_SPEED        60
%define MI_RADIUS       64
%define MI_HEIGHT       68
%define MI_MASS         72
%define MI_DAMAGE       76
%define MI_ACTIVESOUND  80
%define MI_FLAGS        84
%define MI_RAISESTATE   88
%define MI_PAD          92
%define MOBJINFO_SIZE   96

; --------------------------- player_t --------------------------------------
%define PL_MO           0       ; dq
%define PL_STATE        8
%define PL_HEALTH       12
%define PL_ARMORPOINTS  16
%define PL_ARMORTYPE    20
%define PL_READYWEAPON  24
%define PL_PENDINGWEAPON 28
%define PL_WEAPONOWNED  32      ; 9 dd
%define PL_AMMO         68      ; 4 dd
%define PL_MAXAMMO      84      ; 4 dd
%define PL_CARDS        100     ; 6 dd
%define PL_POWERS       124     ; 6 dd
%define PL_ATTACKDOWN   148
%define PL_USEDOWN      152
%define PL_REFIRE       156
%define PL_KILLCOUNT    160
%define PL_ITEMCOUNT    164
%define PL_SECRETCOUNT  168
%define PL_DAMAGECOUNT  172
%define PL_BONUSCOUNT   176
%define PL_EXTRALIGHT   180
%define PL_FIXEDCOLORMAP 184
%define PL_COLORMAP     188
%define PL_VIEWZ        192
%define PL_VIEWHEIGHT   196
%define PL_DELTAVIEWHEIGHT 200
%define PL_BOB          204
%define PL_MESSAGE      208     ; dq -> строка
%define PL_MESSAGETICS  216
%define PL_ATTACKER     224     ; dq
%define PL_PSPRITES     232     ; 2 * pspdef (sx,sy,state,tics) = 2*24
%define PL_DIDSECRET    280
%define PL_BACKPACK     284
%define PL_CHEATS       288
%define CF_GODMODE      2
; флаги объекта на карте (mapthing_t.options)
%define MTF_EASY        1
%define MTF_NORMAL      2
%define MTF_HARD        4
%define MTF_AMBUSH      8
%define MTF_NOTSINGLE   16
%define CF_NOCLIP       1
%define PL_PAD          292
%define PLAYER_SIZE     320

; --------------------------- несколько игроков -----------------------------
%define MAXPLAYERS      2
%define TC_FORWARD      0
%define TC_SIDE         4
%define TC_TURN         8
%define TC_BUTTONS      12
%define TICCMD_SIZE     16
; кольцо команд: тик N лежит в ячейке N & BACKUPMASK
%define BACKUPTICS      16
%define BACKUPMASK      15
%define NET_MAXLEAD     2       ; насколько тиков вперёд разрешено уходить
%define NET_BACKCMDS    4       ; сколько прошлых команд дублируется в пакете
%define MAXSTARTS       8       ; точек появления на карту
%define NET_MAGIC       0x4D4F4F44      ; 'DOOM' -- подпись сетевого пакета

; pspdef: state(dq), tics(dd), sx(dd), sy(dd), pad(dd) = 24
%define PSP_STATE   0
%define PSP_TICS    8
%define PSP_SX      12
%define PSP_SY      16
%define PSP_PAD     20
%define PSPDEF_SIZE 24

%define ps_weapon   0
%define ps_flash    1
%define NUMPSPRITES 2

; --- состояния игрока ---
%define PST_LIVE    0
%define PST_DEAD    1
%define PST_REBORN  2

; --- виды патронов ---
%define am_clip     0
%define am_shell    1
%define am_cell     2
%define am_misl     3
%define NUMAMMO     4
%define am_noammo   5

; --- оружие ---
%define wp_fist         0
%define wp_pistol       1
%define wp_shotgun      2
%define wp_chaingun     3
%define wp_missile      4
%define wp_plasma       5
%define wp_bfg          6
%define wp_chainsaw     7
%define wp_supershotgun 8
%define NUMWEAPONS      9
%define wp_nochange     10

; --- ключи ---
%define it_bluecard     0
%define it_yellowcard   1
%define it_redcard      2
%define it_blueskull    3
%define it_yellowskull  4
%define it_redskull     5
%define NUMCARDS        6

; --- усиления ---
%define pw_invulnerability 0
%define pw_strength        1
%define pw_invisibility    2
%define pw_ironfeet        3
%define pw_allmap          4
%define pw_infrared        5
%define NUMPOWERS          6

%define INVULNTICS  (30*35)
%define INVISTICS   (60*35)
%define INFRATICS   (120*35)
%define IRONTICS    (60*35)

; --------------------------- потолки и лестницы ----------------------------
%define MAXCEILINGS 64
%define CEILSPEED   FRACUNIT
%define CEILWAIT    150

; --- движение потолка ---
%define CL_SECTOR   0
%define CL_TYPE     4
%define CL_BOTH     8       ; нижняя граница
%define CL_TOPH     12      ; верхняя граница
%define CL_SPEED    16
%define CL_CRUSH    20
%define CL_DIR      24      ; 1 вверх, -1 вниз, 0 в стазисе
%define CL_OLDDIR   28
%define CL_TAG      32
%define CL_INUSE    36
%define CEIL_SIZE   40

; типы потолков (как в ceiling_e)
%define CT_LOWERTOFLOOR     0
%define CT_RAISETOHIGHEST   1
%define CT_LOWERANDCRUSH    2
%define CT_CRUSHANDRAISE    3
%define CT_FASTCRUSH        4
%define CT_SILENTCRUSH      5
