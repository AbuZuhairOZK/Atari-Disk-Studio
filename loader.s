; ATR Disk Studio XEX boot loader
; Boots from sectors 1-4, loads the FIRST file in the DOS 2 directory as a
; binary load (XEX) file by following its DOS 2 sector chain, calls INITAD
; after each segment and finally jumps to RUNAD (or the first segment start).
; Works on SD (720) and DOS 2.5 ED (1040) disks with 128-byte sectors.
; Uses sectors 1-4 (sector 4 is marked in use in the VTOC) and memory $0700-$097F.
; If a cartridge still covers $A000-$BFFF after BASIC is switched off, it says so
; and waits for a key, since programs that use that memory would crash.

DDEVIC  = $0300
DUNIT   = $0301
DCOMND  = $0302
DBUFLO  = $0304
DBUFHI  = $0305
DAUX1   = $030A
DAUX2   = $030B
DSKINV  = $E453
CIOV    = $E456
ICCOM   = $0342
ICBAL   = $0344
ICBAH   = $0345
ICAX1   = $034A
ICAX2   = $034B
RUNAD   = $02E0
INITAD  = $02E2
PORTB   = $D301
BASICF  = $03F8
RAMTOP  = $6A
COLOR2  = $02C6
COLOR4  = $02C8
BUF     = $0900
ICBLL   = $0348
ICBLH   = $0349
CH      = $02FC

        .org $0700
        .byte 0                 ; boot flag
        .byte 4                 ; sectors to load
        .word $0700             ; load address
        .word dosini            ; DOSINI

start:  ; --- switch BASIC off (XL/XE) and give programs the full RAM ---
        lda PORTB
        ora #$02
        sta PORTB
        lda #1
        sta BASICF
        ; --- is $A000-$BFFF RAM now, or is a cartridge still there? ---
        lda $BFF0               ; flip every bit; ROM won't change
        eor #$FF
        sta $BFF0
        cmp $BFF0
        bne cart
        lda #$C0                ; all RAM: give programs memory up to $BFFF
        sta RAMTOP
        jsr reopen
        jmp load
cart:   jsr reopen              ; RAMTOP stays below the cartridge
        lda #11                 ; PUT BYTES: the warning text
        sta ICCOM
        lda #<msg
        sta ICBAL
        lda #>msg
        sta ICBAH
        lda #msgend-msg
        sta ICBLL
        lda #0
        sta ICBLH
        ldx #0
        jsr CIOV
        lda #$FF
        sta CH
waitk:  lda CH
        cmp #$FF
        beq waitk
        lda #$FF
        sta CH

load:
        ; --- read directory sector 361, take file #0 ---
        lda #<361
        sta DAUX1
        lda #>361
        sta DAUX2
        jsr readsec
        lda BUF                 ; flags: 0 = never used, bit 7 = deleted
        beq nofile
        bpl gotfil
nofile: jmp fail
gotfil: lda BUF+3
        sta nxt
        lda BUF+4
        sta nxt+1
        lda #0
        sta RUNAD
        sta RUNAD+1

seg:    jsr getb
        bcs done
        sta wr+1
        jsr getb
        bcs done
        sta wr+2
        and wr+1                ; $FFFF header?
        cmp #$FF
        beq seg
        jsr getb
        bcs fail
        sta endlo
        jsr getb
        bcs fail
        sta endhi
        lda first
        bne noset
        inc first
        lda wr+1
        sta fst
        lda wr+2
        sta fst+1
noset:  lda #<dosini
        sta INITAD
        lda #>dosini
        sta INITAD+1
byte:   jsr getb
        bcs fail
wr:     sta $FFFF               ; address patched per byte
        lda wr+1
        cmp endlo
        bne next
        lda wr+2
        cmp endhi
        beq segend
next:   inc wr+1
        bne byte
        inc wr+2
        jmp byte
segend: jsr callin
        jmp seg

done:   lda RUNAD+1
        bne run
        lda fst
        sta RUNAD
        lda fst+1
        sta RUNAD+1
run:    jmp (RUNAD)

callin: jmp (INITAD)
dosini: rts

fail:   lda #$34                ; red screen: disk or file problem
        sta COLOR2
        sta COLOR4
hang:   jmp hang

; --- get next file byte in A, carry set at end of file ---
getb:   ldx idx
        cpx cnt
        bcc have
        lda nxt
        ora nxt+1
        beq eof
        lda nxt
        sta DAUX1
        lda nxt+1
        sta DAUX2
        jsr readsec
        lda BUF+127
        and #$7F
        sta cnt
        lda BUF+125
        and #$03
        sta nxt+1
        lda BUF+126
        sta nxt
        lda #0
        sta idx
        jmp getb
have:   lda BUF,x
        inc idx
        clc
        rts
eof:    sec
        rts

; --- read sector DAUX1/2 from D1: into BUF, red screen on error ---
readsec:
        lda #$31
        sta DDEVIC
        lda #1
        sta DUNIT
        lda #$52
        sta DCOMND
        lda #<BUF
        sta DBUFLO
        lda #>BUF
        sta DBUFHI
        jsr DSKINV
        bmi fail
        rts

; --- reopen the screen editor so the screen moves to the top of RAM ---
reopen: ldx #0
        lda #12                 ; CLOSE #0
        sta ICCOM
        jsr CIOV
        ldx #0
        lda #3                  ; OPEN #0,12,0,"E:"
        sta ICCOM
        lda #<ename
        sta ICBAL
        lda #>ename
        sta ICBAH
        lda #12
        sta ICAX1
        lda #0
        sta ICAX2
        jmp CIOV

msg:    .byte $9B, "CARTRIDGE FOUND. IF THIS CRASHES,", $9B
        .byte "REMOVE IT. ANY KEY TO GO ON.", $9B
msgend:
ename:  .byte "E:", $9B
nxt:    .word 0
idx:    .byte 0
cnt:    .byte 0
endlo:  .byte 0
endhi:  .byte 0
first:  .byte 0
fst:    .word 0
        .byte "ATRDS-XEX"       ; signature ATR Disk Studio looks for
        .res $0900 - *, 0
