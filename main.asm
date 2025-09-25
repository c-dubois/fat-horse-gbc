; ================================
; FAT HORSE PROJECT
; Game Boy Color homebrew with sprite-based horse
; ================================

SECTION "ROM Bank $00", ROM0[$0000]

; Entry point - this is where the Game Boy starts executing code
EntryPoint:
    di                      ; Disable interrupts during setup
    jp Start                ; Jump to main code

; ================================
; ROM HEADER - Required by hardware
; ================================

SECTION "ROM Header", ROM0[$0100]

; This is the "Nintendo logo" area - must contain specific data
; or the Game Boy won't boot! RGBDS will fill this automatically.
    ; Nintendo Logo (required for booting)
    nop                    ; $0100
    jp EntryPoint          ; $0101-$0103: Jump to entry point

; Game title (11 bytes, padded with zeros)
db "FAT HORSE"       ; $0134-$013E: Title shown in emulators

; Game Boy Color flag
db $80                ; $0143: $80 = GBC compatible, $C0 = GBC only

; New licensee code (2 bytes)
db "HM"                   ; $0144-$0145: "company code" (homebrew!)

; Super Game Boy flag  
db $00                    ; $0146: $00 = not SGB enhanced

; Cartridge type
db $00                    ; $0147: $00 = ROM only (no extra chips)

; ROM size
db $00                    ; $0148: $00 = 32KB ROM

; RAM size  
db $00                    ; $0149: $00 = no external RAM

; Destination code
db $01                    ; $014A: $01 = non-Japanese

; Old licensee code
db $33                    ; $014B: $33 = use new licensee code above

; ROM version
db $00                    ; $014C: version 0

; Header checksum (RGBDS calculates this automatically)
db $00                    ; $014D: will be fixed by linker

; Global checksum (RGBDS calculates this automatically)  
dw $0000                  ; $014E-$014F: will be fixed by linker

; ================================
; VARIABLES
; ================================

SECTION "Variables", WRAM0
CurrentDirection:
    ds 1    ; 0=down, 1=left, 2=right, 3=up

HorsePosX:
    ds 1    ; The X coordinate of the horse
HorsePosY:
    ds 1    ; The Y coordinate of the horse

PreviousActionButtonState:
    ds 1    ; Debouncing for A/B buttons

BaseTileNumber:
    ds 1    ; Starting tile number for current horse

; ================================
; HORSE SPRITE DATA
; ================================

SECTION "Horse Sprite Data", ROM0

HorseDownSprites:
    INCBIN "horse-down.2bpp"
HorseDownSpritesEnd:

HorseLeftSprites:
    INCBIN "horse-left.2bpp"
HorseLeftSpritesEnd:

HorseRightSprites:
    INCBIN "horse-right.2bpp"
HorseRightSpritesEnd:

HorseUpSprites:
    INCBIN "horse-up.2bpp"
HorseUpSpritesEnd:

; ================================
; MAIN PROGRAM
; ================================

SECTION "Main", ROM0[$0150]

Start:
    ld sp, $FFFE

    ; Turn off LCD
    ld a, 0
    ld [$FF40], a

    ; Clear OAM 
    ld hl, $FE00
    ld b, 160
    ld a, 0
ClearOAM:
    ld [hl+], a
    dec b
    jr nz, ClearOAM

    ; Initialize variables
    ld a, 0                 
    ld [CurrentDirection], a
    ld a, 80 ; Let's start X at 80
    ld [HorsePosX], a
    ld a, 72 ; Let's start Y at 72
    ld [HorsePosY], a

    ; --- Turn on the APU (Sound Hardware) ---
    ld a, $80       ; Bit 7: 1=On, 0=Off
    ld [$FF26], a   ; NR52 - Master sound switch
    ld a, $77       ; Set volume for both speakers to max
    ld [$FF24], a   ; NR50 - Channel control / Volume
    ld a, $FF       ; Enable all sound channels on both speakers
    ld [$FF25], a   ; NR51 - Selection of Sound output terminal

    ; Load ALL horse sprites into different VRAM areas
    ld hl, HorseDownSprites
    ld de, $8000
    ld bc, HorseDownSpritesEnd - HorseDownSprites
    call CopyMemory
    
    ld hl, HorseLeftSprites
    ld de, $8480
    ld bc, HorseLeftSpritesEnd - HorseLeftSprites
    call CopyMemory
    
    ld hl, HorseRightSprites
    ld de, $86C0
    ld bc, HorseRightSpritesEnd - HorseRightSprites
    call CopyMemory
    
    ld hl, HorseUpSprites
    ld de, $8240
    ld bc, HorseUpSpritesEnd - HorseUpSprites
    call CopyMemory

    ; Set initial base tile number
    ld a, 0
    ld [BaseTileNumber], a

    ; Set up sprite palette
    ld a, %00011011
    ld [$FF48], a

    ; Set up the initial horse sprites
    call SetupHorseSprites

    ; Turn on LCD with sprites
    ld a, %10000010
    ld [$FF40], a

MainLoop:
    call WaitVBlank
    call CheckInput
    jr MainLoop

; ================================
; HORSE SPRITE FUNCTIONS
; ================================

; Sets the base tile number based on the current direction.
; This assumes all horse graphics are already loaded into VRAM.
UpdateBaseTileNumber:
    ld a, [CurrentDirection]
    cp 0 ; is direction Down?
    jr z, .SetDown
    cp 1 ; is direction Left?
    jr z, .SetLeft
    cp 2 ; is direction Right?
    jr z, .SetRight
    ; Otherwise, direction is Up

.SetUp:
    ld a, 36    ; Base tile number for Up horse (starts at $8240)
    jr .Done
.SetDown:
    ld a, 0     ; Base tile number for Down horse (starts at $8000)
    jr .Done
.SetLeft:
    ld a, 72    ; Base tile number for Left horse (starts at $8480)
    jr .Done
.SetRight:
    ld a, 108   ; Base tile number for Right horse (starts at $86C0)
.Done:
    ld [BaseTileNumber], a
    ret

; Set up 6x6 grid of sprites to display the horse using nested loops
SetupHorseSprites:
    ld hl, $FE00                ; Start of OAM
    ld a, [HorsePosY]
    ld d, a                     ; Load initial Y coordinate
    ld a, [BaseTileNumber]
    ld c, a                     ; Load initial Tile Number
    ld b, 6                     ; Initialize outer loop counter for 6 rows

.row_loop:
    ld a, [HorsePosX]
    ld e, a                     ; Load and reset the initial X for the start of each row

    ; save ONLY the row counter (b) using the AF register pair
    ld a, b
    push af

    ld b, 6                     ; Initialize inner loop counter for 6 columns
.col_loop:
    ld a, d                     ; Current Y position
    ld [hl+], a
    ld a, e                     ; Current X position
    ld [hl+], a
    ld a, c                     ; Current Tile number
    ld [hl+], a
    inc c                       ; Next tile
    ld a, 0                     ; Attributes (palette 0, no flip)
    ld [hl+], a

    ld a, e                     ; Move to next sprite position (X + 8)
    add 8
    ld e, a

    dec b                       ; Decrement column counter
    jr nz, .col_loop            ; Loop if not done with columns

    ; restore ONLY the row counter
    pop af
    ld b, a

    ld a, d                     ; Move to the next row (Y + 8)
    add 8
    ld d, a

    dec b                       ; Decrement row counter
    jr nz, .row_loop            ; Loop if not done with rows
    ret

; ================================
; INPUT HANDLING
; ================================

CheckInput:
    ; --- Part 1: Handle D-Pad Movement ---
    ld a, $20       ; Select the D-Pad for reading
    ld [$FF00], a
    ld a, [$FF00]
    ld a, [$FF00]
    cpl
    and $0F

    ; Check one direction at a time. If a direction is pressed, the handler
    ; will be called and this function will exit for this frame.
    bit 0, a
    jr nz, HandleRight
    bit 1, a
    jr nz, HandleLeft
    bit 2, a
    jr nz, HandleUp
    bit 3, a
    jr nz, HandleDown

    ; --- Part 2: Handle A/B Buttons (if not moving) ---
    ld a, $10       ; Select the Action Buttons for reading
    ld [$FF00], a
    ld a, [$FF00]
    ld a, [$FF00]
    cpl
    and $0F

    ; Debounce: Find which buttons were just pressed THIS frame
    ld b, a                               ; b = current button state
    ld a, [PreviousActionButtonState]     ; a = previous state

    push af                               ; Temporarily save A (previous state) on the stack
    ld a, b                               ; Copy B (current state) into A
    ld [PreviousActionButtonState], a     ; Now we can legally save the new state for the next frame
    pop af                                ; Restore A (previous state) from the stack

    xor b                                 ; a (previous) XOR b (current) = changed buttons
    and b                                 ; result AND b (current) = newly pressed buttons

    ; Check for newly pressed A or B buttons
    bit 0, a ; Was A (bit 0) just pressed?
    call nz, PlayNeighSound

    bit 1, a ; Was B (bit 1) just pressed?
    call nz, PlaySnortSound

    ret

HandleRight:
    ld a, 2 ; Set direction to Right
    ld [CurrentDirection], a
    ld hl, HorsePosX
    inc [hl] ; Move right
    ; Boundary check: Don't go off the right edge
    ld a, [hl]
    cp 160 - 48 + 8 ; Horse X must be < (Screen Width - Horse Width + Sprite Offset)
    jr c, UpdateGraphics ; If less, update is okay
    dec [hl] ; If not, move back
    jr UpdateGraphics

HandleLeft:
    ld a, 1 ; Set direction to Left
    ld [CurrentDirection], a
    ld hl, HorsePosX
    dec [hl] ; Move left
    ; Boundary check: Don't go off the left edge
    ld a, [hl]
    cp 8 ; Sprite X coordinate starts at 8
    jr nc, UpdateGraphics ; If >= 8, update is okay
    inc [hl] ; If not, move back
    jr UpdateGraphics

HandleUp:
    ld a, 3 ; Set direction to Up
    ld [CurrentDirection], a
    ld hl, HorsePosY
    dec [hl] ; Move up
    ; Boundary check: Don't go off the top edge
    ld a, [hl]
    cp 16 ; Sprite Y coordinate starts at 16
    jr nc, UpdateGraphics ; If >= 16, update is okay
    inc [hl] ; If not, move back
    jr UpdateGraphics

HandleDown:
    ld a, 0 ; Set direction to Down
    ld [CurrentDirection], a
    ld hl, HorsePosY
    inc [hl] ; Move down
    ; Boundary check: Don't go off the bottom edge
    ld a, [hl]
    cp 144 - 48 + 16 ; Horse Y must be < (Screen Height - Horse Height + Sprite Offset)
    jr c, UpdateGraphics ; If less, update is okay
    dec [hl] ; If not, move back
    ; Fall through to update graphics

UpdateGraphics:
    call UpdateBaseTileNumber
    call SetupHorseSprites
    ret

; ================================
; SOUND FUNCTIONS
; ================================

PlayNeighSound:
    ; Uses Channel 1 (Pulse wave with a frequency sweep) for a high, falling pitch.
    ld a, %01001100 ; Sweep: time=4, direction=decrease, shift=4
    ld [$FF10], a   ; NR10 - Sweep register
    ld a, %10000000 ; Wave Duty: 50%, Sound Length: short
    ld [$FF11], a   ; NR11 - Sound length/Wave pattern duty
    ld a, %11110011 ; Volume Envelope: Start Vol=15, dir=decrease, step time=3
    ld [$FF12], a   ; NR12 - Volume Envelope
    ld a, $7F       ; Frequency LSB (lower 8 bits)
    ld [$FF13], a   ; NR13 - Frequency lo
    ld a, %11000110 ; Trigger (bit 7), Use Length (bit 6), Freq MSB (upper 3 bits)
    ld [$FF14], a   ; NR14 - Frequency hi
    ret

PlaySnortSound:
    ; Uses Channel 4 (Noise generator) for a short burst of static.
    ld a, %00011111 ; Sound Length: short
    ld [$FF20], a   ; NR41 - Sound length
    ld a, %11100010 ; Volume Envelope: Start Vol=14, dir=decrease, step time=2
    ld [$FF21], a   ; NR42 - Volume Envelope
    ld a, %00110001 ; Noise Type: Clock shift=3, width=7-bit, divisor=1
    ld [$FF22], a   ; NR43 - Polynomial Counter
    ld a, %11000000 ; Trigger (bit 7), Use Length (bit 6)
    ld [$FF23], a   ; NR44 - Counter/consecutive; Initial
    ret

; ================================
; UTILITY FUNCTIONS
; ================================

CopyMemory:
    ld a, [hl+]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, CopyMemory
    ret

WaitVBlank:
    ld a, [$FF44]
    cp 144
    jr c, WaitVBlank
    ret