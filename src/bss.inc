; ===========================================================================
;  bss.inc -- неинициализированные данные (секция .bss, nobits)
; ===========================================================================

; ------------------------------ платформа ----------------------------------
    alignb 16
g_hinst:        resq 1
g_hwnd:         resq 1
g_hdc:          resq 1
g_hcursor:      resq 1
g_fh:           resq 1
g_logfh:        resq 1
g_written:      resq 1
g_errmsg:       resq 1

g_qpf:          resq 1
g_lasttime:     resq 1
g_nowtime:      resq 1
g_ticacc:       resq 1
g_ticlen:       resq 1

g_wc:           resb 80
g_rect:         resb 16
g_msg:          resb 48
g_pt:           resb 8
g_pt2:          resb 8

g_scale:        resd 1
g_winw:         resd 1
g_winh:         resd 1
g_wndw:         resd 1
g_wndh:         resd 1
g_quit:         resb 1
g_active:       resb 1
g_shotmode:     resb 1
g_mousegrab:    resb 1
g_autowalk:     resb 1
g_autofire:     resb 1
g_automap0:     resb 1
g_startlevel:   resb 1
g_godmode:      resb 1
g_startskill:   resb 1
g_haveskill:    resb 1
g_wipetest:     resb 1
g_shottic:      resd 1
g_gametic:      resd 1
g_ticsrun:      resd 1
g_mousex:       resd 1
g_mousey:       resd 1

    alignb 16
g_keydown:      resb NUMKEYS
g_keyhit:       resb NUMKEYS
    alignb 16
g_logbuf:       resb 4096
g_logpos:       resd 1
g_numbuf:       resb 32

; ------------------------------ видео --------------------------------------
    alignb 16
g_bmi:          resb 40 + 1024
g_palette:      resb 768
    alignb 16
screens:        resb SCREENWIDTH*SCREENHEIGHT
    alignb 16
wipe_start:     resb SCREENWIDTH*SCREENHEIGHT
wipe_end:       resb SCREENWIDTH*SCREENHEIGHT
wipe_y:         resd SCREENWIDTH
wipe_state:     resd 1
st_facedir:     resd 1
st_facecount:   resd 1
st_rampage:     resd 1
st_lastdmg:     resd 1
wi_stage:       resd 1
wi_shown:       resd 1
wi_pause:       resd 1
wi_pkills:      resd 1
wi_pitems:      resd 1
wi_psecret:     resd 1
wi_ptime:       resd 1
wi_final:       resd 4
mus_step:       resd 1
mus_cnt:        resd 1
mus_env:        resd 1
mus_ph1:        resd 1
mus_ph2:        resd 1
mus_ph3:        resd 1
    alignb 16
g_bmpbuf:       resb 14 + 40 + 1024 + SCREENWIDTH*SCREENHEIGHT

; ------------------------------ математика ---------------------------------
    alignb 16
g_itmp:         resd 1
g_itmp2:        resd 1
g_dtmp:         resq 1
    alignb 16
finesine:       resd 10240
finetangent:    resd 4096
tantoangle:     resd 2049
    alignb 16
colormaps:      resb 34*256

; ------------------------------ память -------------------------------------
    alignb 16
g_zone:         resq 1
g_zonepos:      resq 1

; ------------------------------ карта --------------------------------------
    alignb 16
vertexes:       resb MAXVERTEXES*VERTEX_SIZE
sectors:        resb MAXSECTORS*SECTOR_SIZE
sides:          resb MAXSIDES*SIDE_SIZE
lines:          resb MAXLINES*LINE_SIZE
walldefs:       resb MAXWALLDEFS*WALLDEF_SIZE
thingdefs:      resb 512*THINGDEF_SIZE
seclinebuf:     resd MAXLINES*2
numvertexes:    resd 1
numsectors:     resd 1
numsides:       resd 1
numlines:       resd 1
numwalldefs:    resd 1
numthings:      resd 1
cursector:      resd 1
validcount:     resd 1

    alignb 16
bmaporgx:       resd 1
bmaporgy:       resd 1
bmapwidth:      resd 1
bmapheight:     resd 1
bmapnum:        resd 1
blocktotal:     resd 1
blockcount:     resd 16384
blockofs:       resd 16384
blocklists:     resd 65536
blocklinks:     resq 16384

; ------------------------------ рендер -------------------------------------
    alignb 16
viewx:          resd 1
viewy:          resd 1
viewz:          resd 1
viewangle:      resd 1
viewsin:        resd 1
viewcos:        resd 1
viewsector:     resd 1
centerx:        resd 1
centery:        resd 1
centerxfrac:    resd 1
centeryfrac:    resd 1
projection:     resd 1
focallength:    resd 1
viewwidth:      resd 1
viewheight:     resd 1
pspritescale:   resd 1
pspriteiscale:  resd 1
skytexturemid:  resd 1
skytexture:     resd 1
skyflatnum:     resd 1
clipangle:      resd 1
extralight:     resd 1
portaldepth:    resd 1
    alignb 16
fixedcolormap:  resq 1
floorplane:     resq 1
ceilingplane:   resq 1
planezlight:    resq 1
walllights:     resq 1
maskedtexturecol: resq 1
planeheight:    resd 1
basexscale:     resd 1
baseyscale:     resd 1
lastvisplane:   resd 1
lastopening:    resd 1
ds_index:       resd 1

    alignb 16
xtoviewangle:   resd 321
viewangletox:   resd 4096
yslope:         resd 256
distscale:      resd 320
screenheightarray: resd 320
negonearray:    resd 320
ceilingclip:    resd 320
floorclip:      resd 320
spanstart:      resd 256
cachedheight:   resd 256
cacheddistance: resd 256
cachedxstep:    resd 256
cachedystep:    resd 256
    alignb 16
zlight:         resq LIGHTLEVELS*MAXLIGHTZ
scalelight:     resq LIGHTLEVELS*MAXLIGHTSCALE
    alignb 16
visplanes:      resb MAXVISPLANES*VISPLANE_SIZE
drawsegs:       resb MAXDRAWSEGS*DRAWSEG_SIZE
openings:       resd MAXOPENINGS

; --- параметры столбца/полосы ---
    alignb 16
dc_x:           resd 1
dc_yl:          resd 1
dc_yh:          resd 1
dc_iscale:      resd 1
dc_texturemid:  resd 1
dc_texmask:     resd 1
dc_source:      resq 1
dc_colormap:    resq 1
fuzzpos:        resd 1
ds_x1:          resd 1
ds_x2:          resd 1
ds_y:           resd 1
ds_xfrac:       resd 1
ds_yfrac:       resd 1
ds_xstep:       resd 1
ds_ystep:       resd 1
ds_source:      resq 1
ds_colormap:    resq 1

; --- состояние отрезка стены ---
    alignb 16
rw_x:           resd 1
rw_stopx:       resd 1
rw_start:       resd 1
rw_scale:       resd 1
rw_scalestep:   resd 1
rw_distance:    resd 1
rw_normalangle: resd 1
rw_angle1:      resd 1
rw_centerangle: resd 1
rw_offset:      resd 1
rw_hyp:         resd 1
rw_midtexturemid: resd 1
rw_toptexturemid: resd 1
rw_bottomtexturemid: resd 1
rw_lineofs:     resd 1
rw_sideofs:     resd 1
rw_frontsec:    resd 1
rw_backsec:     resd 1
rw_v1x:         resd 1
rw_v1y:         resd 1
rw_v2x:         resd 1
rw_v2y:         resd 1
worldtop:       resd 1
worldbottom:    resd 1
worldhigh:      resd 1
worldlow:       resd 1
topfrac:        resd 1
topstep:        resd 1
bottomfrac:     resd 1
bottomstep:     resd 1
pixhigh:        resd 1
pixhighstep:    resd 1
pixlow:         resd 1
pixlowstep:     resd 1
midtexture:     resd 1
toptexture:     resd 1
bottomtexture:  resd 1
maskedtexture:  resd 1
markfloor:      resd 1
markceiling:    resd 1
segtextured:    resd 1

; ------------------------------ текстуры -----------------------------------
    alignb 16
textures:       resb NUMTEXTURES*TX_SIZE
flats:          resq NUMFLATS
flattranslation: resd NUMFLATS
texrandseed:    resd 1
tg_param:       resd 1
tg_tex:         resd 1
tg_base:        resd 1
tg_ramp:        resd 1
tg_w:           resd 1
tg_h:           resd 1

; ------------------------------ звук ---------------------------------------
    alignb 16
sfxdata:        resq NUMSFX
sfxlen:         resd NUMSFX
sndchans:       resb SNDCHANNELS*CHAN_SIZE
hwaveout:       resq 1
wfx:            resb 24
sndseed:        resd 1
sndphase:       resd 1
sndprev:        resd 1
    alignb 16
wavehdrs:       resb SNDNUMBUF*WAVEHDR_SIZE
sndbuffers:     resb SNDNUMBUF*SNDBUFBYTES

; ------------------------------ объекты ------------------------------------
    alignb 16
mobjs:          resb MAXMOBJS*MOBJ_SIZE
nummobjs:       resd 1
maxmobjused:    resd 1
dbg_walls:      resd 1
dbg_addline:    resd 1

; ------------------------------ игрок --------------------------------------
    alignb 16
playermo:       resq 1
player:         resb PLAYER_SIZE
pl_forwardmove: resd 1
pl_sidemove:    resd 1
pl_angleturn:   resd 1
pl_buttons:     resd 1
pl_newweapon:   resd 1
gameskill:      resd 1
fastparm:       resd 1
respawnmonsters: resd 1
leveltime:      resd 1
totalsecret:    resd 1
totalkills:     resd 1
totalitems:     resd 1
g_exitlevel:    resb 1
g_secretexit:   resb 1
g_paused:       resb 1
g_curlevel:     resb 1
g_gamestate:    resb 1
am_active:      resb 1
am_scale:       resd 1
am_cx:          resd 1
am_cy:          resd 1
am_color:       resd 1
am_tmp:         resd 1
m_item:         resd 1
prndseed:       resd 1

; ------------------------------ столкновения -------------------------------
    alignb 16
tmthing:        resq 1
tmflags:        resd 1
tmx:            resd 1
tmy:            resd 1
tmbbox:         resd 4
tmfloorz:       resd 1
tmceilingz:     resd 1
tmdropoffz:     resd 1
tmsector:       resd 1
ceilingline:    resd 1
numspechit:     resd 1
spechit:        resd MAXSPECHIT
floatok:        resd 1
opentop:        resd 1
openbottom:     resd 1
openrange:      resd 1
lowfloor:       resd 1
slidemo:        resq 1
bestslidefrac:  resd 1
secondslidefrac: resd 1
bestslideline:  resd 1
secondslideline: resd 1
tmxmove:        resd 1
tmymove:        resd 1
sl_leadx:       resd 1
sl_leady:       resd 1
sl_trailx:      resd 1
sl_traily:      resd 1
shootthing:     resq 1
usething:       resq 1
linetarget:     resq 1
bombspot:       resq 1
bombsource:     resq 1
shootz:         resd 1
attackrange:    resd 1
aimslope:       resd 1
topslope:       resd 1
bottomslope:    resd 1
la_damage:      resd 1
bulletslope:    resd 1
sightzstart:    resd 1
bombdamage:     resd 1
bombdist:       resd 1
chd1:           resd 1
chd2:           resd 1
    alignb 16
trace:          resd 4
ldv:            resd 4
intercepts:     resb MAXINTERCEPTS*IC_SIZE
numintercepts:  resd 1
ic_frac:        resd 1
pt_x1:          resd 1
pt_y1:          resd 1
pt_x2:          resd 1
pt_y2:          resd 1
pt_flags:       resd 1
pt_func:        resq 1
pt_xt1:         resd 1
pt_yt1:         resd 1
pt_xt2:         resd 1
pt_yt2:         resd 1
pt_mapxstep:    resd 1
pt_mapystep:    resd 1
pt_partial:     resd 1
pt_xstep:       resd 1
pt_ystep:       resd 1
pt_xintercept:  resd 1
pt_yintercept:  resd 1

; ------------------------------ механизмы ----------------------------------
    alignb 16
doors:          resb MAXDOORS*DOOR_SIZE
plats:          resb MAXPLATS*PLAT_SIZE
floormoves:     resb MAXFLOORS*FLOOR_SIZE
lightfx:        resb MAXLIGHTS*LIGHT_SIZE
ceilmoves:      resb MAXCEILINGS*CEIL_SIZE
nofit:          resd 1
crushchange:    resd 1

; ------------------------------ спрайты ------------------------------------
    alignb 16
spriteframes:   resq NUMSPRITES*MAXSPRFRAMES*8
vissprites:     resb MAXVISSPRITES*VS_SIZE
numvissprites:  resd 1
secspr:         resb MAXSECTORS
spritelights:   resq 1
mfloorclip:     resq 1
mceilingclip:   resq 1
sprtopscreen:   resd 1
spryscale:      resd 1
psp_y:          resd 1
clipbot:        resd 320
cliptop:        resd 320
    alignb 16
bakebuf:        resb 256*256
bake_w:         resd 1
bake_h:         resd 1
sp_color:       resd 1
sp_edge:        resd 1
cr_spr:         resd 1
cr_body:        resd 1
cr_head:        resd 1
cr_h:           resd 1
cr_w:           resd 1
cr_style:       resd 1
cr_bw:          resd 1
art_h:          resd 1
    alignb 8
art_palovr:     resq 1
art_count:      resd 1
g_curtint:      resd 1
