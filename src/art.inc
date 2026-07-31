; ===========================================================================
;  art.inc -- СЂРёСЃРѕРІР°РЅРЅС‹Рµ СЃРїСЂР°Р№С‚С‹ (РїРёРєСЃРµР»СЊ-Р°СЂС‚ РїСЂСЏРјРѕ РІ РёСЃС…РѕРґРЅРёРєРµ)
;
;  db С€РёСЂРёРЅР°, РІС‹СЃРѕС‚Р°, Р·Р°С‚РµРј 8 РёРЅРґРµРєСЃРѕРІ РїР°Р»РёС‚СЂС‹, Р·Р°С‚РµРј СЃС‚СЂРѕРєРё РїРѕ С€РёСЂРёРЅРµ:
;  '.' -- РїСЂРѕР·СЂР°С‡РЅРѕ, '1'..'8' -- С†РІРµС‚ РёР· РїР°Р»РёС‚СЂС‹ Р°СЂС‚Р°.
; ===========================================================================

%define TROOPAL PAL_ORANGE+2, PAL_ORANGE+7, PAL_ORANGE+13, PAL_BROWN+16, PAL_GRAY+29, PAL_RED+1, PAL_TAN+3, PAL_BROWN+24
%define SARGPAL PAL_FLESH+1, PAL_FLESH+5, PAL_FLESH+10, PAL_FLESH+14, PAL_GRAY+29, PAL_RED+2, PAL_TAN+2, PAL_BROWN+20
%define HEADPAL PAL_RED+2, PAL_RED+7, PAL_RED+13, PAL_RED+19, PAL_GRAY+29, PAL_BLUE+2, PAL_TAN+2, PAL_GRAY+6

art_head_fa:
    db 30, 34
    db HEADPAL
    db '....7...................7.....'
    db '.....77...............77......'
    db '......7...............7.......'
    db '.........5555555555...........'
    db '.......55111111111155.........'
    db '......5111111111111115........'
    db '.....511111111111111115.......'
    db '....51111111111111111115......'
    db '....51111111111111111115......'
    db '...5111111111111111111115.....'
    db '...5111111111111111111115.....'
    db '...5111115555555511111115.....'
    db '...5111158888888511111115.....'
    db '...5111158866688511111115.....'
    db '...5111158866688511111115.....'
    db '...5111158888888511111115.....'
    db '...5111115555555511111115.....'
    db '...5111111111111111111115.....'
    db '...5222111111111111112225.....'
    db '....522211111111111222 5......'
    db '....52222111111111222225......'
    db '.....5222277777772222 5.......'
    db '.....52222766667722225........'
    db '......5222277777722225........'
    db '......522222222222 5..........'
    db '.......52222222222 5..........'
    db '.......533222222335...........'
    db '........5333333335............'
    db '........53333333 5............'
    db '.........5333333 5............'
    db '.........544444 5.............'
    db '..........54444 5.............'
    db '..........5444 5..............'
    db '...........555................'

; ===========================================================================
;  Р‘Р°СЂРѕРЅ (SPR_BOSS): РІС‹СЃРѕРєРёР№, СЃ СЂРѕРіР°РјРё Рё РєРѕРїС‹С‚Р°РјРё
; ===========================================================================
%define BOSSPAL PAL_TEAL+2, PAL_TEAL+7, PAL_TEAL+11, PAL_GREEN+14, PAL_GRAY+29, PAL_RED+1, PAL_TAN+3, PAL_BROWN+22

art_boss_fa:
    db 28, 50
    db BOSSPAL
    db '....7................7......'
    db '.....77............77.......'
    db '......77..........77........'
    db '.......7..........7.........'
    db '........51111111115.........'
    db '.......5111111111115........'
    db '.......5116111161115........'
    db '.......5111111111115........'
    db '.......5117777777115........'
    db '........511111111 5.........'
    db '.........5111111 5..........'
    db '.........52222225...........'
    db '......5522222222255.........'
    db '.....522222222222225........'
    db '....52222222222222225.......'
    db '...5222222222222222225......'
    db '...5221111111111112225......'
    db '..52211111111111111225......'
    db '..52211111111111111225......'
    db '..52211111111111111225......'
    db '..52233111111111133225......'
    db '..52233311111113332225......'
    db '..52233333333333332225......'
    db '..52233333333333332225......'
    db '...522333333333333225.......'
    db '...522333333333333225.......'
    db '....52333333333322 5........'
    db '....5233333333333225........'
    db '.....52333333333225.........'
    db '.....52333.33333225.........'
    db '.....5233...3332 5..........'
    db '.....533.....3335...........'
    db '.....533.....3335...........'
    db '.....533.....3335...........'
    db '.....533.....3335...........'
    db '.....533.....3335...........'
    db '.....533.....3335...........'
    db '....5433.....33445..........'
    db '....5433.....33445..........'
    db '....5443.....34445..........'
    db '....5443.....34445..........'
    db '....5444.....44445..........'
    db '....5444.....44445..........'
    db '...54444.....444445.........'
    db '...54444.....444445.........'
    db '..574444.....4444475........'
    db '..774444.....4444477........'
    db '..777444.....4447777........'
    db '..777744.....4477777........'
    db '..777777.....7777777........'

art_boss_sa:
    db 28, 50
    db BOSSPAL
    db '.........7.........7........'
    db '..........77.....77.........'
    db '..........77.....7..........'
    db '...........7.....7..........'
    db '.........5111111115.........'
    db '........511111111115........'
    db '........511611111115........'
    db '........511111111115........'
    db '........511777777115........'
    db '.........5111111115.........'
    db '..........51111115..........'
    db '..........5222225...........'
    db '........552222222255........'
    db '.......5222222222225........'
    db '......52222222222225........'
    db '.....522222222222225........'
    db '.....522111111112225........'
    db '.....521111111111225........'
    db '.....521111111111225........'
    db '.....521111111111225........'
    db '.....523311111133225........'
    db '.....523331111333225........'
    db '.....523333333333225........'
    db '.....523333333333225........'
    db '......52333333333325........'
    db '......52333333333325........'
    db '.......5233333333325........'
    db '.......5233333333325........'
    db '........523333333325........'
    db '........523333333325........'
    db '........5233....3325........'
    db '........533......335........'
    db '........533......335........'
    db '........533......335........'
    db '........533......335........'
    db '........533......335........'
    db '........533......335........'
    db '.......5433......3445.......'
    db '.......5433......3445.......'
    db '.......5443......3445.......'
    db '.......5443......3445.......'
    db '.......5444......4445.......'
    db '.......5444......4445.......'
    db '......544444.....44445......'
    db '......544444.....44445......'
    db '.....5744444.....444475.....'
    db '.....7744444.....4444775....'
    db '.....7774444.....44477775...'
    db '.....7777444.....447777775..'
    db '.....7777777.....777777775..'

; ===========================================================================
;  РџРѕС‚РµСЂСЏРЅРЅР°СЏ РґСѓС€Р° (SPR_SKUL): РіРѕСЂСЏС‰РёР№ С‡РµСЂРµРї
; ===========================================================================
%define SKULPAL PAL_GRAY+1, PAL_GRAY+6, PAL_GRAY+12, PAL_GRAY+18, PAL_GRAY+29, PAL_RED+1, PAL_ORANGE+2, PAL_YELLOW+1

art_skul_fa:
    db 22, 24
    db SKULPAL
    db '.....8..........8.....'
    db '....78....8....87.....'
    db '...778...78...877.....'
    db '...777..7777..777.....'
    db '....77.577775.777.....'
    db '.....7511111157.......'
    db '....751111111157......'
    db '...75111111111157.....'
    db '...7511111111115 7....'
    db '...751166111661157....'
    db '...751166111661157....'
    db '...75111111111157.....'
    db '....751111111157......'
    db '....751111111157......'
    db '.....7511111157.......'
    db '.....75111111 57......'
    db '......751111157.......'
    db '......75121215 7......'
    db '.......751215 7.......'
    db '.......7512157........'
    db '........75215.........'
    db '........7515..........'
    db '.........755..........'
    db '.........77...........'

; ===========================================================================
;  РўСЂСѓРї (РѕР±С‰РёР№ РєР°РґСЂ СЃРјРµСЂС‚Рё, РїР°Р»РёС‚СЂР° РїРѕРґРјРµРЅСЏРµС‚СЃСЏ РїРѕРґ РєР°Р¶РґРѕРіРѕ РјРѕРЅСЃС‚СЂР°)
; ===========================================================================
art_corpse:
    db 26, 12
    db PAL_FLESH+2, PAL_FLESH+8, PAL_BROWN+8, PAL_BROWN+16, PAL_GRAY+29, PAL_RED+4, PAL_RED+10, PAL_GRAY+24
    db '.........5555.............'
    db '.......55322355...........'
    db '.....553222223355.........'
    db '....5322222222233555......'
    db '...53222113333333322555...'
    db '..5322211133333333322255..'
    db '..5322111333333333333225..'
    db '..5533311333333333333355..'
    db '...5566333333333333665....'
    db '....66666333333336666.....'
    db '..7766666666666666666677..'
    db '.777777777777777777777777.'

; ===========================================================================
;  РџСЂРёРІСЏР·РєР° Р°СЂС‚Р° Рє СЃРїСЂР°Р№С‚Р°Рј
;   СЂР°РєСѓСЂСЃС‹: 0,1 Р°РЅС„Р°СЃ; 2 РїСЂРѕС„РёР»СЊ; 3,4 СЃРїРёРЅР°; 5 СЃРїРёРЅР° Р·РµСЂРє.; 6 РїСЂРѕС„РёР»СЊ Р·РµСЂРє.;
;            7 Р°РЅС„Р°СЃ Р·РµСЂРє.
;   РєР°РґСЂС‹:  FMA -- С€Р°Рі A, Р°С‚Р°РєР°, Р±РѕР»СЊ;  FMB -- С€Р°Рі B;  FMD -- СЃРјРµСЂС‚СЊ
; ===========================================================================

; ===========================================================================
;  Привязка арта к спрайтам
;   ракурсы: 0,1 анфас; 2 профиль; 3,4 спина; 5 спина зерк.; 6 профиль зерк.;
;            7 анфас зерк.
;   кадры:  FMA -- шаг A, атака, боль;  FMB -- шаг B;  FMD -- смерть
; ===========================================================================
%define FMA 0xF5
%define FMB 0x0A
%define FMALL 0xFF
%define FMD 0x1F00
%define RF  0x03        ; анфас
%define RFX 0x80        ; анфас зеркально
%define RS  0x04        ; профиль
%define RSX 0x40        ; профиль зеркально
%define RB  0x18        ; спина
%define RBX 0x20        ; спина зеркально

; арт, спрайт, маска кадров, маска ракурсов, отражение, вид, палитра
%macro ARTE 7
    dq %1
    dd %2, %3, %4, %5
    dd %6, 0
    dq %7
%endmacro
    align 8
artlist:
    ; ------------------------------ оружие ------------------------------
    ARTE art_pistol,   SPR_PISG, 0xFFFF, 0xFF, 0, 1, 0
    ARTE art_shotgun,  SPR_SHTG, 0xFFFF, 0xFF, 0, 1, 0
    ARTE art_fist,     SPR_PUNG, 0xFFFF, 0xFF, 0, 1, 0
    ARTE art_chaingun, SPR_CHGG, 0xFFFF, 0xFF, 0, 1, 0
    ARTE art_launcher, SPR_MISG, 0xFFFF, 0xFF, 0, 1, 0
    ARTE art_plasma,   SPR_PLSG, 0xFFFF, 0xFF, 0, 1, 0
    ARTE art_bfg,      SPR_BFGG, 0xFFFF, 0xFF, 0, 1, 0
    ARTE art_saw,      SPR_SAWG, 0xFFFF, 0xFF, 0, 1, 0

    ; ------------------------------ зомби -------------------------------
    ARTE art_poss_fa, SPR_POSS, FMA,   RF,  0, 0, 0
    ARTE art_poss_fa, SPR_POSS, FMA,   RFX, 1, 0, 0
    ARTE art_poss_fb, SPR_POSS, FMB,   RF,  0, 0, 0
    ARTE art_poss_fb, SPR_POSS, FMB,   RFX, 1, 0, 0
    ARTE art_poss_sa, SPR_POSS, FMA,   RS,  0, 0, 0
    ARTE art_poss_sa, SPR_POSS, FMA,   RSX, 1, 0, 0
    ARTE art_poss_sb, SPR_POSS, FMB,   RS,  0, 0, 0
    ARTE art_poss_sb, SPR_POSS, FMB,   RSX, 1, 0, 0
    ARTE art_poss_ba, SPR_POSS, FMALL, RB,  0, 0, 0
    ARTE art_poss_ba, SPR_POSS, FMALL, RBX, 1, 0, 0
    ARTE art_corpse,  SPR_POSS, FMD,   0xFF, 0, 0, 0

    ; --------------------- сержант: та же фигура, синяя ------------------
    ARTE art_poss_fa, SPR_SPOS, FMA,   RF,  0, 0, pal_spos
    ARTE art_poss_fa, SPR_SPOS, FMA,   RFX, 1, 0, pal_spos
    ARTE art_poss_fb, SPR_SPOS, FMB,   RF,  0, 0, pal_spos
    ARTE art_poss_fb, SPR_SPOS, FMB,   RFX, 1, 0, pal_spos
    ARTE art_poss_sa, SPR_SPOS, FMA,   RS,  0, 0, pal_spos
    ARTE art_poss_sa, SPR_SPOS, FMA,   RSX, 1, 0, pal_spos
    ARTE art_poss_sb, SPR_SPOS, FMB,   RS,  0, 0, pal_spos
    ARTE art_poss_sb, SPR_SPOS, FMB,   RSX, 1, 0, pal_spos
    ARTE art_poss_ba, SPR_SPOS, FMALL, RB,  0, 0, pal_spos
    ARTE art_poss_ba, SPR_SPOS, FMALL, RBX, 1, 0, pal_spos
    ARTE art_corpse,  SPR_SPOS, FMD,   0xFF, 0, 0, 0

    ; ------------------------------ имп ---------------------------------
    ARTE art_troo_fa, SPR_TROO, FMA,   RF,  0, 0, 0
    ARTE art_troo_fa, SPR_TROO, FMA,   RFX, 1, 0, 0
    ARTE art_troo_fb, SPR_TROO, FMB,   RF,  0, 0, 0
    ARTE art_troo_fb, SPR_TROO, FMB,   RFX, 1, 0, 0
    ARTE art_troo_sa, SPR_TROO, FMALL, RS,  0, 0, 0
    ARTE art_troo_sa, SPR_TROO, FMALL, RSX, 1, 0, 0
    ARTE art_troo_ba, SPR_TROO, FMALL, RB,  0, 0, 0
    ARTE art_troo_ba, SPR_TROO, FMALL, RBX, 1, 0, 0
    ARTE art_corpse,  SPR_TROO, FMD,   0xFF, 0, 0, 0

    ; ------------------------------ демон -------------------------------
    ARTE art_sarg_fa, SPR_SARG, FMALL, RF,  0, 0, 0
    ARTE art_sarg_fa, SPR_SARG, FMALL, RFX, 1, 0, 0
    ARTE art_sarg_sa, SPR_SARG, FMALL, RS,  0, 0, 0
    ARTE art_sarg_sa, SPR_SARG, FMALL, RSX, 1, 0, 0
    ARTE art_sarg_fa, SPR_SARG, FMALL, RB,  0, 0, 0
    ARTE art_sarg_fa, SPR_SARG, FMALL, RBX, 1, 0, 0
    ARTE art_corpse,  SPR_SARG, FMD,   0xFF, 0, 0, 0

    ; --------------------------- какодемон ------------------------------
    ARTE art_head_fa, SPR_HEAD, FMALL, 0xFF, 0, 0, 0
    ARTE art_corpse,  SPR_HEAD, FMD,   0xFF, 0, 0, 0

    ; ------------------------------ барон -------------------------------
    ARTE art_boss_fa, SPR_BOSS, FMALL, RF,  0, 0, 0
    ARTE art_boss_fa, SPR_BOSS, FMALL, RFX, 1, 0, 0
    ARTE art_boss_sa, SPR_BOSS, FMALL, RS,  0, 0, 0
    ARTE art_boss_sa, SPR_BOSS, FMALL, RSX, 1, 0, 0
    ARTE art_boss_fa, SPR_BOSS, FMALL, RB,  0, 0, 0
    ARTE art_boss_fa, SPR_BOSS, FMALL, RBX, 1, 0, 0
    ARTE art_corpse,  SPR_BOSS, FMD,   0xFF, 0, 0, 0

    ; ----------------------- потерянная душа ----------------------------
    ARTE art_skul_fa, SPR_SKUL, 0xFFFF, 0xFF, 0, 0, 0

    ; ------------------------------ игрок -------------------------------
    ARTE art_poss_fa, SPR_PLAY, FMA,   RF,  0, 0, 0
    ARTE art_poss_fa, SPR_PLAY, FMA,   RFX, 1, 0, 0
    ARTE art_poss_sa, SPR_PLAY, FMALL, RS,  0, 0, 0
    ARTE art_poss_sa, SPR_PLAY, FMALL, RSX, 1, 0, 0
    ARTE art_poss_ba, SPR_PLAY, FMALL, RB,  0, 0, 0
    ARTE art_poss_ba, SPR_PLAY, FMALL, RBX, 1, 0, 0
    ARTE art_corpse,  SPR_PLAY, FMD,   0xFF, 0, 0, 0

    ; ----------------------------- предметы -----------------------------
    ARTE art_armor,      SPR_ARM1, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_armor,      SPR_ARM2, 0xFFFF, 0xFF, 0, 0, pal_arm2
    ARTE art_stim,       SPR_STIM, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_medi,       SPR_MEDI, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_clip,       SPR_CLIP, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_ammobox,    SPR_AMMO, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_shell,      SPR_SHEL, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_shellbox,   SPR_SBOX, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_rocket,     SPR_ROCK, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_rockbox,    SPR_BROK, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_cell,       SPR_CELL, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_cellpack,   SPR_CELP, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_bpack,      SPR_BPAK, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_key,        SPR_BKEY, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_key,        SPR_YKEY, 0xFFFF, 0xFF, 0, 0, pal_keyy
    ARTE art_key,        SPR_RKEY, 0xFFFF, 0xFF, 0, 0, pal_keyr
    ARTE art_barrel,     SPR_BAR1, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_sphere,     SPR_SOUL, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_sphere,     SPR_PINV, 0xFFFF, 0xFF, 0, 0, pal_pinv
    ARTE art_sphere,     SPR_PSTR, 0xFFFF, 0xFF, 0, 0, pal_pstr
    ARTE art_sphere,     SPR_PINS, 0xFFFF, 0xFF, 0, 0, pal_pins
    ARTE art_potion,     SPR_BON1, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_helmet,     SPR_BON2, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_suit,       SPR_SUIT, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_map,        SPR_PMAP, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_map,        SPR_PVIS, 0xFFFF, 0xFF, 0, 0, pal_pins

    ; ------------------------- стволы на полу ---------------------------
    ARTE art_p_shotgun,  SPR_SHOT, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_p_chaingun, SPR_MGUN, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_p_launcher, SPR_LAUN, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_p_plasma,   SPR_PLAS, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_p_bfg,      SPR_BFUG, 0xFFFF, 0xFF, 0, 0, 0
    ARTE art_p_saw,      SPR_CSAW, 0xFFFF, 0xFF, 0, 0, 0

    dq 0
    dd 0, 0, 0, 0
    dd 0, 0
    ; --------------------- попадания и снаряды --------------------------
    ARTE art_puff_a,  SPR_PUFF, 0x0001, 0xFF, 0, 0, 0
    ARTE art_puff_b,  SPR_PUFF, 0x0002, 0xFF, 0, 0, 0
    ARTE art_puff_c,  SPR_PUFF, 0x0004, 0xFF, 0, 0, 0
    ARTE art_puff_d,  SPR_PUFF, 0x0008, 0xFF, 0, 0, 0
    ARTE art_blud_a,  SPR_BLUD, 0x0001, 0xFF, 0, 0, 0
    ARTE art_blud_b,  SPR_BLUD, 0x0002, 0xFF, 0, 0, 0
    ARTE art_blud_c,  SPR_BLUD, 0x0004, 0xFF, 0, 0, 0
    ARTE art_ball_a,  SPR_BAL1, 0x0001, 0xFF, 0, 0, 0
    ARTE art_ball_b,  SPR_BAL1, 0x0002, 0xFF, 0, 0, 0
    ARTE art_expl_a,  SPR_BAL1, 0x0004, 0xFF, 0, 0, 0
    ARTE art_expl_b,  SPR_BAL1, 0x0008, 0xFF, 0, 0, 0
    ARTE art_expl_c,  SPR_BAL1, 0x0010, 0xFF, 0, 0, 0
    ARTE art_ball_a,  SPR_BAL7, 0x0003, 0xFF, 0, 0, 0
    ARTE art_expl_a,  SPR_BAL7, 0x0004, 0xFF, 0, 0, 0
    ARTE art_expl_b,  SPR_BAL7, 0x0018, 0xFF, 0, 0, 0
    ARTE art_expl_a,  SPR_MISL, 0x0002, 0xFF, 0, 0, 0
    ARTE art_expl_b,  SPR_MISL, 0x0004, 0xFF, 0, 0, 0
    ARTE art_expl_c,  SPR_MISL, 0x0008, 0xFF, 0, 0, 0
    ARTE art_expl_a,  SPR_BEXP, 0x0003, 0xFF, 0, 0, 0
    ARTE art_expl_b,  SPR_BEXP, 0x0004, 0xFF, 0, 0, 0
    ARTE art_expl_c,  SPR_BEXP, 0x0018, 0xFF, 0, 0, 0
    ARTE art_tfog_a,  SPR_TFOG, 0x0003, 0xFF, 0, 0, 0
    ARTE art_tfog_b,  SPR_TFOG, 0x001C, 0xFF, 0, 0, 0
    ARTE art_tfog_c,  SPR_TFOG, 0x03E0, 0xFF, 0, 0, 0

    ARTE art_flash,   SPR_FLSH, 0xFFFF, 0xFF, 0, 1, 0

    dq 0
