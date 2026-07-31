; ===========================================================================
;  DOOM на x86-64 ассемблере (NASM, вывод -f bin: PE собирается вручную)
;
;  сборка:  build.ps1   ->  doom.exe
; ===========================================================================

    bits 64
    default abs
    cpu x64

%define BSS_RVA 0x00800000

%include "src/macros.inc"
%include "src/win.inc"
%include "src/defs.inc"
%include "src/sounds.inc"

    org IMAGEBASE
%include "src/pe64.inc"

; --------------------------------- код -------------------------------------
%include "src/i_main.asm"
%include "src/i_video.asm"
%include "src/m_zone.asm"
%include "src/m_fixed.asm"
%include "src/v_pal.asm"
%include "src/info.asm"
%include "src/r_tex.asm"
%include "src/r_draw.asm"
%include "src/r_plane.asm"
%include "src/r_main.asm"
%include "src/r_seg.asm"
%include "src/r_things.asm"
%include "src/r_art.asm"
%include "src/p_setup.asm"
%include "src/p_mobj.asm"
%include "src/p_mobj2.asm"
%include "src/p_map.asm"
%include "src/p_map2.asm"
%include "src/p_enemy.asm"
%include "src/p_inter.asm"
%include "src/p_user.asm"
%include "src/p_spec.asm"
%include "src/p_ceil.asm"
%include "src/s_sound.asm"
%include "src/st_bar.asm"
%include "src/am_map.asm"
%include "src/m_menu.asm"
%include "src/f_wipe.asm"
%include "src/g_game.asm"

; --------------------------------- данные ----------------------------------
%include "src/art_hud.inc"
%include "src/art_weap.inc"
%include "src/art_mon.inc"
%include "src/art_fx.inc"
%include "src/art_items.inc"
%include "src/art.inc"
%include "src/levels.inc"
%include "src/data.inc"
%include "src/imports.inc"

    align 0x1000, db 0
text_end:

; --------------------------------- bss -------------------------------------
    absolute IMAGEBASE + BSS_RVA
bss_start:
%include "src/bss.inc"
bss_end:
