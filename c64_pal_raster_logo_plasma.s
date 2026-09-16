; =============================================================
; c64_pal_raster_logo_plasma.s
; PAL C64 demo (NO IRQs) — raster-polled timing.
; IMPORTANT FIX: Entry point is now at $1000 (Start is first), so SYS4096 works.
; Includes r7e improvements: frame sync + safe raster waits. IRQs stay disabled.
; =============================================================
; Build:
;   acme -f cbm -o c64_pal_raster_logo_plasma.prg c64_pal_raster_logo_plasma.s
; Run:
;   x64sc -autostart c64_pal_raster_logo_plasma.prg
; =============================================================

; ---------------- BASIC stub: 10 SYS4096 ----------------
* = $0801
!word $080b
!word 10
!byte $9e
!text "4096"
!byte 0
!word 0

; ---------------- Hardware constants ----------------
BORDERCOL   = $d020
BGCOL       = $d021
RASTER      = $d012
CTRL1       = $d011
CTRL2       = $d016
MEMPTR      = $d018
VICIRQEN    = $d01a
VICIRQFLAG  = $d019
CIA1_ICR    = $dc0d
CIA2_PRA    = $dd00
CIA2_ICR    = $dd0d

SCREEN      = $0400
COLOR       = $d800
CHARSET     = $2000
CHARSET_LOGO= $3000
SPRITE_DATA = $2800

SPRITE_PTRS = SCREEN + 1016
SPRITE_ENA  = $d015
SPRITE_XEXP = $d01d
SPRITE_YEXP = $d017
SPRITE_COL0 = $d027
SPRITE_MC   = $d01c
SPRITE_MC0  = $d025
SPRITE_MC1  = $d026

; Character base helpers
SetCharBase2000: lda #$18 : sta MEMPTR : rts
SetCharBase3000: lda #$1c : sta MEMPTR : rts   ; (unused in SAFE build)

; ---------------- Zero page ----------------
ZP_SrcLo    = $fb
ZP_SrcHi    = $fc
ZP_DstLo    = $fd
ZP_DstHi    = $fe
ZP_TmpA     = $f8
ZP_TmpB     = $f9
ZP_TmpC     = $fa

; ---------------- State vars ----------------
FrameCount      = $033a
ScrollIdx       = $033b
SmoothScroll    = $033c
ColorCycle      = $033d
WavePhase       = $033e
StarPhase       = $033f
LogoPhase       = $0340
PlasmaPhase     = $0341
Logo1StartX     = $0342
Logo1Len        = $0343
Logo2StartX     = $0344
Logo2Len        = $0345
Flag_ShineEnabled = $0346
Flag_UseLogoFont  = $0347
FontValid         = $0348
SpriteIndex       = $0349

; ---------------- Tables ----------------
* = $0900
RowScrLo:  !for i,0,24 { !byte <(SCREEN + i*40) }
RowScrHi:  !for i,0,24 { !byte >(SCREEN + i*40) }
RowColLo:  !for i,0,24 { !byte <(COLOR  + i*40) }
RowColHi:  !for i,0,24 { !byte >(COLOR  + i*40) }

Sine256:
!byte 128,131,134,137,140,143,146,149,152,156,159,162,165,168,171,174
!byte 176,179,182,185,188,191,193,196,199,201,204,206,209,211,213,216
!byte 218,220,222,224,226,228,230,232,234,236,237,239,240,242,243,245
!byte 246,247,248,249,250,251,252,252,253,254,254,255,255,255,255,255
!byte 255,255,255,255,255,255,254,254,253,252,252,251,250,249,248,247
!byte 246,245,243,242,240,239,237,236,234,232,230,228,226,224,222,220
!byte 218,216,213,211,209,206,204,201,199,196,193,191,188,185,182,179
!byte 176,174,171,168,165,162,159,156,152,149,146,143,140,137,134,131
!byte 128,125,122,119,116,113,110,107,104,100,97,94,91,88,85,82
!byte 80,77,74,71,68,65,63,60,57,55,52,50,47,45,43,40
!byte 38,36,34,32,30,28,26,24,22,20,19,17,16,14,13,11
!byte 10,9,8,7,6,5,4,4,3,2,2,1,1,1,1,1
!byte 1,1,1,1,1,1,2,2,3,4,4,5,6,7,8,9
!byte 10,11,13,14,16,17,19,20,22,24,26,28,30,32,34,36
!byte 38,40,43,45,47,50,52,55,57,60,63,65,68,71,74,77
!byte 80,82,85,88,91,94,97,100,104,107,110,113,116,119,122,125

SpritePhase8: !byte 0,32,64,96,128,160,192,224
PlasmaColors: !byte 6,14,3,1,3,14,6,0,6,14,3,1,3,14,6,0, 9,8,7,2,7,8,9,0,9,8,7,2,7,8,9,0
RainbowBar:   !byte 6,14,3,13,1,13,3,14,6,14,3,13,1,13,3,14
Fire16:       !byte 0,9,2,8,2,10,7,10,15,7,10,7,8,2,9,0
Ice16:        !byte 6,14,3,1,1,3,14,6,0,6,14,3,1,1,3,14

ScrollText:
!scr "    *** ultimate horizonwarp demo *** "
!scr "featuring: plasma waves * color bars * sprite multiplex * "
!scr "smooth scroll * raster splits * animated charset * "
!scr "and maximum c64 eye candy! *** "
!scr "coded with pure 6502 assembly *** "
!byte 0

LogoText:
!scr "   ** horizon warp **   "
!byte 0
LogoText2:
!scr " maximum eye candy demo "
!byte 0

; ---------------- Code ----------------
* = $1000

; >>> ENTRY POINT <<<  (SYS 4096 jumps here)
Start:
    sei
    ldx #$ff
    txs

    ; Disable CIAs and VIC IRQs
    lda CIA1_ICR : lda CIA2_ICR
    lda #$7f
    sta CIA1_ICR : sta CIA2_ICR
    lda CIA1_ICR : lda CIA2_ICR
    lda #$00
    sta VICIRQEN
    lda VICIRQFLAG
    sta VICIRQFLAG

    ; Point NMI vector to harmless RTI (RESTORE safe)
    lda #<NMIStub : sta $0318
    lda #>NMIStub : sta $0319

    ; Blue theme
    lda #$06
    sta BORDERCOL
    sta BGCOL

    ; VIC bank 0, screen=$0400, charset=$2000
    lda CIA2_PRA
    and #%11111100
    ora #%00000011
    sta CIA2_PRA
    jsr SetCharBase2000
    lda #$1b : sta CTRL1
    lda #$08 : sta CTRL2

    jsr ClearScreen
    jsr ClearColor
    jsr CopyROMCharset
    jsr ModifyCharset
    jsr InstallCustomFont

    ; SAFE: use fallback logo font only
    lda #$00 : sta Flag_UseLogoFont
    jsr BuildLogoFont

    jsr InitState
    jsr InitSprites
    jsr CreateSpriteData
    jsr DrawLogo
    jsr DrawBorders

    ; KEEP IRQs DISABLED (no CLI)

MainLoop:
    jsr WaitFrameStart     ; solid frame alignment at raster 0
    inc FrameCount
    jsr KeyPoll            ; RTS in this SAFE build
    jsr UpdateScroll

    lda #50   : jsr WaitRasterA : jsr TopSection
    lda #120  : jsr WaitRasterA : jsr MidSection
    lda #170  : jsr WaitRasterA : jsr PlasmaEffect
    lda #220  : jsr WaitRasterA : jsr RasterBars

    lda #$06 : sta BORDERCOL
    jmp MainLoop

; NMI stub placed AFTER Start so entry is correct
NMIStub: rti

; ---------------- Frame start sync (wait for raster wrap to 0) --------
WaitFrameStart:
    ; Wait until we're >= 250 to ensure we observe wrap
@wait_low:
    lda RASTER
    cmp #250
    bcc @wait_low
    ; Wait for 0 with badline clear
@wait_zero:
    lda RASTER
    bne @wait_zero
    bit CTRL1
    bmi @wait_zero
    rts

; ---------------- Raster wait (A = line < 256) ----------------
; Safer variant: if already passed, wait next frame first.
WaitRasterA:
    sta ZP_TmpA
    lda RASTER
    cmp ZP_TmpA
    beq @okline
    bcs @wait_next_frame
@okline:
@lp:
    lda RASTER
    cmp ZP_TmpA
    bne @lp
    bit CTRL1
    bmi @lp
    rts
@wait_next_frame:
    jsr WaitFrameStart
    jmp WaitRasterA

; ---------------- Sections ----------------
TopSection:
    ldx FrameCount
    lda Sine256,x
    lsr : lsr : lsr : lsr
    tax
    lda RainbowBar,x
    sta BORDERCOL
    lda Flag_ShineEnabled
    beq @no
    jsr LogoShine
@no: rts

MidSection:
    jsr UpdateSprites
    jsr ColorWaveEffect
    rts

; ---------------- Scroller ----------------
UpdateScroll:
    lda SmoothScroll
    beq @shift
    dec SmoothScroll
    lda SmoothScroll
    ora #$08
    sta CTRL2
    rts
@shift:
    lda #$07
    sta SmoothScroll
    lda #$0f
    sta CTRL2

    ldx #0
@sh:
    lda SCREEN+22*40+1,x
    sta SCREEN+22*40+0,x
    lda COLOR+22*40+1,x
    sta COLOR+22*40+0,x
    inx
    cpx #39
    bne @sh

    ldx ScrollIdx
    lda ScrollText,x
    bne @ok
    ldx #0
    lda ScrollText,x
@ok:
    sta SCREEN+22*40+39

    lda FrameCount
    lsr
    and #$0f
    tax
    lda Fire16,x
    sta COLOR+22*40+39

    inc ScrollIdx
    ldx ScrollIdx
    lda ScrollText,x
    bne @noloop
    lda #0
    sta ScrollIdx
@noloop:
    rts

; ---------------- Sprite Effects ----------------
UpdateSprites:
    lda #$ff : sta SPRITE_ENA
    lda #$ff : sta SPRITE_MC

    lda FrameCount
    lsr : lsr
    and #$0f
    tax
    lda Fire16,x : sta SPRITE_MC0
    lda Ice16,x  : sta SPRITE_MC1

    lda #0 : sta $d010

    ldx #0
@pos:
    stx SpriteIndex
    lda FrameCount
    clc
    adc SpritePhase8,x
    tay
    lda Sine256,y
    lsr
    clc
    adc #24
    ldy SpriteIndex
    tya
    asl
    tay
    sta $d000,y

    ldx SpriteIndex
    lda FrameCount
    asl
    clc
    adc SpritePhase8,x
    tay
    lda Sine256,y
    clc
    adc #50
    ldy SpriteIndex
    tya
    asl
    tay
    iny
    sta $d000,y

    ldx SpriteIndex
    inx
    cpx #8
    bne @pos

    lda FrameCount
    lsr : lsr
    and #$0f
    tax
    lda PlasmaColors,x
    ldx #0
@col:
    sta SPRITE_COL0,x
    inx
    cpx #8
    bne @col

    lda FrameCount
    and #$1f
    cmp #$10
    bcs @noexp
    lda #$ff : sta SPRITE_XEXP : sta SPRITE_YEXP
    rts
@noexp:
    lda #$00 : sta SPRITE_XEXP : sta SPRITE_YEXP
    rts

; ---------------- Color Wave Effect ----------------
ColorWaveEffect:
    lda WavePhase
    sta ZP_TmpA
    ldx #5
@row:
    lda RowColLo,x : sta ZP_DstLo
    lda RowColHi,x : sta ZP_DstHi
    lda ZP_TmpA
    and #$0f
    tay
    lda RainbowBar,y
    ldy #0
@cl:
    sta (ZP_DstLo),y
    iny
    cpy #40
    bne @cl
    lda ZP_TmpA
    clc
    adc #3
    sta ZP_TmpA
    inx
    cpx #16
    bne @row
    inc WavePhase
    rts

; ---------------- Plasma Effect ----------------
PlasmaEffect:
    lda PlasmaPhase
    and #$0f
    tax
    lda PlasmaColors,x
    sta BGCOL
    inc PlasmaPhase
    rts

; ---------------- Raster Bars ----------------
RasterBars:
    ldx #0
@bars:
    lda FrameCount
    clc
    adc StarPhase
    clc
    adc Sine256,x
    and #$0f
    tay
    lda Ice16,y
    sta BORDERCOL
    ldy #2
@delay:
    dey
    bne @delay
    inx
    cpx #20
    bne @bars
    lda #6
    sta BORDERCOL
    inc StarPhase
    rts

; ---------------- Logo Shine (color waves on logo rows) ----------------
LogoShine:
    ; Line 1 (row 2 colors)
    ldx #0
@l1:
    cpx Logo1Len
    beq @l2
    lda FrameCount
    clc
    adc #4
    stx ZP_TmpB
    adc ZP_TmpB
    and #$0f
    tay
    lda Fire16,y          ; A=color
    pha
    lda #< (COLOR+2*40) : sta ZP_DstLo
    lda #> (COLOR+2*40) : sta ZP_DstHi
    txa
    clc
    adc Logo1StartX
    tay
    pla
    sta (ZP_DstLo),y
    inx
    bne @l1
@l2:
    ; Line 2 (row 3 colors)
    ldx #0
@l3:
    cpx Logo2Len
    beq @done
    lda FrameCount
    stx ZP_TmpB
    clc
    adc ZP_TmpB
    and #$0f
    tay
    lda Ice16,y
    pha
    lda #< (COLOR+3*40) : sta ZP_DstLo
    lda #> (COLOR+3*40) : sta ZP_DstHi
    txa
    clc
    adc Logo2StartX
    tay
    pla
    sta (ZP_DstLo),y
    inx
    bne @l3
@done:
    rts

; ---------------- Logo Drawing (center + drop shadow) ----------------
DrawLogo:
    ; ---- Line 1 ----
    ldx #0
@len1:
    lda LogoText,x
    beq @gotlen1
    inx
    bne @len1
@gotlen1:
    txa : eor #$ff : clc : adc #41 : lsr : tax : stx Logo1StartX
    ldy #0
@cnt1:
    lda LogoText,y
    beq @st1
    iny
    bne @cnt1
@st1:
    sty Logo1Len

    lda #<(SCREEN + 2*40)
    clc
    adc Logo1StartX
    sta ZP_SrcLo
    lda #>(SCREEN + 2*40)
    clc
    adc #0
    sta ZP_SrcHi

    lda #<(SCREEN + 3*40 + 1)
    clc
    adc Logo1StartX
    sta ZP_DstLo
    lda #>(SCREEN + 3*40 + 1)
    clc
    adc #0
    sta ZP_DstHi

    ldy #0
@draw1:
    cpy Logo1Len
    beq @line2
    lda LogoText,y
    sta (ZP_SrcLo),y          ; main
    lda LogoText,y
    sta (ZP_DstLo),y          ; shadow

    ; color main row2 (Y+Logo1StartX)
    sty ZP_TmpC
    lda #< (COLOR+2*40) : sta ZP_TmpA
    lda #> (COLOR+2*40) : sta ZP_TmpB
    lda ZP_TmpC : clc : adc Logo1StartX : tay
    lda #$01 : sta (ZP_TmpA),y
    ldy ZP_TmpC

    ; color shadow row3 col+1
    sty ZP_TmpC
    lda #< (COLOR+3*40+1) : sta ZP_TmpA
    lda #> (COLOR+3*40+1) : sta ZP_TmpB
    lda ZP_TmpC : clc : adc Logo1StartX : tay
    lda #$02 : sta (ZP_TmpA),y
    ldy ZP_TmpC

    iny
    bne @draw1

@line2:
    ; ---- Line 2 ----
    ldx #0
@len2:
    lda LogoText2,x
    beq @gotlen2
    inx
    bne @len2
@gotlen2:
    txa : eor #$ff : clc : adc #41 : lsr : tax : stx Logo2StartX

    ldy #0
@cnt2:
    lda LogoText2,y
    beq @st2
    iny
    bne @cnt2
@st2:
    sty Logo2Len

    lda #<(SCREEN + 3*40)
    clc
    adc Logo2StartX
    sta ZP_SrcLo
    lda #>(SCREEN + 3*40)
    clc
    adc #0
    sta ZP_SrcHi

    lda #<(SCREEN + 4*40 + 1)
    clc
    adc Logo2StartX
    sta ZP_DstLo
    lda #>(SCREEN + 4*40 + 1)
    clc
    adc #0
    sta ZP_DstHi

    ldy #0
@draw2:
    cpy Logo2Len
    beq @done
    lda LogoText2,y
    sta (ZP_SrcLo),y
    lda LogoText2,y
    sta (ZP_DstLo),y

    ; color main row3
    sty ZP_TmpC
    lda #< (COLOR+3*40) : sta ZP_TmpA
    lda #> (COLOR+3*40) : sta ZP_TmpB
    lda ZP_TmpC : clc : adc Logo2StartX : tay
    lda #$0e : sta (ZP_TmpA),y
    ldy ZP_TmpC

    ; color shadow row4 col+1
    sty ZP_TmpC
    lda #< (COLOR+4*40+1) : sta ZP_TmpA
    lda #> (COLOR+4*40+1) : sta ZP_TmpB
    lda ZP_TmpC : clc : adc Logo2StartX : tay
    lda #$02 : sta (ZP_TmpA),y
    ldy ZP_TmpC

    iny
    bne @draw2
@done:
    rts

; ---------------- Border decorations ----------------
DrawBorders:
    ldx #0
    lda #$40
@top:
    sta SCREEN+5*40,x
    lda #$03
    sta COLOR+5*40,x
    lda #$40
    inx
    cpx #40
    bne @top

    ldx #0
    lda #$40
@bot:
    sta SCREEN+22*40,x
    lda #$06
    sta COLOR+22*40,x
    lda #$40
    inx
    cpx #40
    bne @bot
    rts

; ---------------- Charset ROM copy ----------------
CopyROMCharset:
    lda $01
    pha
    lda #$33
    sta $01

    lda #$00 : sta ZP_SrcLo
    lda #$d0 : sta ZP_SrcHi
    lda #<CHARSET : sta ZP_DstLo
    lda #>CHARSET : sta ZP_DstHi

    ldx #8
@page:
    ldy #0
@cpy:
    lda (ZP_SrcLo),y
    sta (ZP_DstLo),y
    iny
    bne @cpy
    inc ZP_SrcHi
    inc ZP_DstHi
    dex
    bne @page

    pla
    sta $01
    rts

; ---------------- Modify + Custom Font ----------------
ModifyCharset:
    lda #<(CHARSET + $40*8) : sta ZP_DstLo
    lda #>(CHARSET + $40*8) : sta ZP_DstHi
    ldy #0
    lda #$ff : sta (ZP_DstLo),y : iny
    lda #$00 : sta (ZP_DstLo),y : iny
    lda #$ff : sta (ZP_DstLo),y : iny
    lda #$00 : sta (ZP_DstLo),y : iny
    lda #$ff : sta (ZP_DstLo),y : iny
    lda #$00 : sta (ZP_DstLo),y : iny
    lda #$ff : sta (ZP_DstLo),y : iny
    lda #$00 : sta (ZP_DstLo),y
    rts

InstallCustomFont:
    ; In-place safe boldening: A' = A OR (A>>1)
    lda #<CHARSET : sta ZP_DstLo
    lda #>CHARSET : sta ZP_DstHi
    ldx #0
@char:
    ldy #0
@row:
    lda (ZP_DstLo),y
    pha
    lsr
    sta ZP_TmpA
    pla
    ora ZP_TmpA
    sta (ZP_DstLo),y
    iny
    cpy #8
    bne @row
    clc
    lda ZP_DstLo : adc #8 : sta ZP_DstLo
    bcc @noc
    inc ZP_DstHi
@noc:
    inx
    bne @char
    rts

; ---------------- Fallback logo font builder ($3000) ----------------
BuildLogoFont:
    ; Horizontal smear into CHARSET_LOGO
    lda #<CHARSET : sta ZP_SrcLo
    lda #>CHARSET : sta ZP_SrcHi
    lda #<CHARSET_LOGO : sta ZP_DstLo
    lda #>CHARSET_LOGO : sta ZP_DstHi
    ldx #0
@H:
    ldy #0
@HR:
    lda (ZP_SrcLo),y
    sta ZP_TmpA
    lsr
    sta ZP_TmpB
    lda ZP_TmpA
    asl
    and #$fe
    ora ZP_TmpA
    ora ZP_TmpB
    sta (ZP_DstLo),y
    iny
    cpy #8
    bne @HR
    clc
    lda ZP_SrcLo : adc #8 : sta ZP_SrcLo
    bcc @Hncs
    inc ZP_SrcHi
@Hncs:
    clc
    lda ZP_DstLo : adc #8 : sta ZP_DstLo
    bcc @Hncd
    inc ZP_DstHi
@Hncd:
    inx
    bne @H

    ; Vertical smear in-place in CHARSET_LOGO
    lda #<CHARSET_LOGO : sta ZP_SrcLo
    lda #>CHARSET_LOGO : sta ZP_SrcHi
    ldx #0
@V:
    lda #0 : sta ZP_TmpB
    ldy #0
@VR:
    lda (ZP_SrcLo),y
    ora ZP_TmpB
    sta (ZP_SrcLo),y
    sta ZP_TmpB
    iny
    cpy #8
    bne @VR
    clc
    lda ZP_SrcLo : adc #8 : sta ZP_SrcLo
    bcc @Vncs
    inc ZP_SrcHi
@Vncs:
    inx
    bne @V
    rts

; ---------------- Keyboard polling (SAFE: disabled) ----------------
KeyPoll:
    rts

; ---------------- Sprite Data Creation ----------------
CreateSpriteData:
    lda #<SPRITE_DATA : sta ZP_DstLo
    lda #>SPRITE_DATA : sta ZP_DstHi
    ldy #0
    lda #0
@c1:
    sta (ZP_DstLo),y
    iny
    bne @c1
    inc ZP_DstHi
    ldy #0
@c2:
    sta (ZP_DstLo),y
    iny
    bne @c2

    lda #<SPRITE_DATA : sta ZP_DstLo
    lda #>SPRITE_DATA : sta ZP_DstHi

    ldy #0
    lda #%00000000 : sta (ZP_DstLo),y : iny
    lda #%01111110 : sta (ZP_DstLo),y : iny
    lda #%00000000 : sta (ZP_DstLo),y : iny
    lda #%00000010 : sta (ZP_DstLo),y : iny
    lda #%10101010 : sta (ZP_DstLo),y : iny
    lda #%10000000 : sta (ZP_DstLo),y : iny
    lda #%00001010 : sta (ZP_DstLo),y : iny
    lda #%10101010 : sta (ZP_DstLo),y : iny
    lda #%10100000 : sta (ZP_DstLo),y : iny
    lda #%00101010 : sta (ZP_DstLo),y : iny
    lda #%10101010 : sta (ZP_DstLo),y : iny
    lda #%10101000 : sta (ZP_DstLo),y : iny
    lda #%00101010 : sta (ZP_DstLo),y : iny
    lda #%10101010 : sta (ZP_DstLo),y : iny
    lda #%10101000 : sta (ZP_DstLo),y : iny
    lda #%00101010 : sta (ZP_DstLo),y : iny
    lda #%10101010 : sta (ZP_DstLo),y : iny
    lda #%10101000 : sta (ZP_DstLo),y : iny
    lda #%00101010 : sta (ZP_DstLo),y : iny
    lda #%10101010 : sta (ZP_DstLo),y : iny
    lda #%10101000 : sta (ZP_DstLo),y : iny
    lda #%00101010 : sta (ZP_DstLo),y : iny
    lda #%10101010 : sta (ZP_DstLo),y : iny
    lda #%10101000 : sta (ZP_DstLo),y : iny
    lda #%00001010 : sta (ZP_DstLo),y : iny
    lda #%10101010 : sta (ZP_DstLo),y : iny
    lda #%10100000 : sta (ZP_DstLo),y : iny
    lda #%00000010 : sta (ZP_DstLo),y : iny
    lda #%10101010 : sta (ZP_DstLo),y : iny
    lda #%10000000 : sta (ZP_DstLo),y : iny
    lda #%00000000 : sta (ZP_DstLo),y : iny
    lda #%01111110 : sta (ZP_DstLo),y : iny
    lda #%00000000 : sta (ZP_DstLo),y : iny

    ldx #1
@copy_all:
    lda #<SPRITE_DATA : sta ZP_SrcLo
    lda #>SPRITE_DATA : sta ZP_SrcHi

    txa
    asl : asl : asl : asl : asl : asl   ; *64
    clc
    adc #<SPRITE_DATA
    sta ZP_DstLo
    lda #>SPRITE_DATA
    clc
    adc #0
    sta ZP_DstHi

    ldy #0
@copy:
    lda (ZP_SrcLo),y
    sta (ZP_DstLo),y
    iny
    cpy #64
    bne @copy

    inx
    cpx #8
    bne @copy_all
    rts

; ---------------- Init ----------------
InitState:
    lda #0
    sta FrameCount
    sta ScrollIdx
    sta ColorCycle
    sta WavePhase
    sta StarPhase
    sta LogoPhase
    sta PlasmaPhase
    lda #7
    sta SmoothScroll

    lda #1
    sta Flag_ShineEnabled
    lda #0
    sta Flag_UseLogoFont
    sta FontValid

    ; SID noise init
    lda #$ff : sta $d40e : sta $d40f
    lda #$80 : sta $d412
    rts

InitSprites:
    lda #$a0
    ldx #0
@ip:
    sta SPRITE_PTRS,x
    inx
    cpx #8
    bne @ip
    rts

; ---------------- Clear helpers ----------------
ClearScreen:
    lda #$20
    ldx #0
@c1:
    sta $0400,x
    sta $0500,x
    sta $0600,x
    inx
    bne @c1
    ldx #231
@c2:
    sta $0700,x
    dex
    bpl @c2
    rts

ClearColor:
    lda #$06
    ldx #0
@cc1:
    sta $d800,x
    sta $d900,x
    sta $da00,x
    inx
    bne @cc1
    ldx #231
@cc2:
    sta $db00,x
    dex
    bpl @cc2
    rts
