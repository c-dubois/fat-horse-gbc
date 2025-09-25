; ================================
; FAT HORSE PROJECT - LESSON 1
; Minimal Game Boy Color ROM
; ================================

SECTION "ROM Bank $00", ROM0[$0000]

; Entry point - this is where the Game Boy starts executing code
EntryPoint:
    di                      ; Disable interrupts during setup
    jp Start                ; Jump to our main code

; ================================
; ROM HEADER - Required by hardware
; ================================

SECTION "ROM Header", ROM0[$0100]

; This is the "Nintendo logo" area - must contain specific data
; or the Game Boy won't boot! RGBDS will fill this automatically.
    ; Nintendo Logo (required for booting)
    nop                    ; $0100
    jp EntryPoint          ; $0101-$0103: Jump to our entry point

; Game title (11 bytes, padded with zeros)
db "FAT HORSE"       ; $0134-$013E: Title shown in emulators

; Game Boy Color flag
db $80                ; $0143: $80 = GBC compatible, $C0 = GBC only

; New licensee code (2 bytes)
db "HM"                   ; $0144-$0145: Our "company code" (homebrew!)

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
; HORSE TILE DATA - From converted sprites
; ================================

SECTION "Horse Data", ROM0

HorseDownTiles:
    INCBIN "horse-down.2bpp"
HorseDownTilesEnd:

HorseLeftTiles:
    INCBIN "horse-left.2bpp" 
HorseLeftTilesEnd:

HorseRightTiles:
    INCBIN "horse-right.2bpp"
HorseRightTilesEnd:

HorseUpTiles:
    INCBIN "horse-up.2bpp"
HorseUpTilesEnd:

SECTION "Variables", WRAM0
CurrentDirection:
    ds 1    ; 1 byte to store current direction (0=down, 1=left, 2=right, 3=up)

; ================================
; MAIN PROGRAM
; ================================

SECTION "Main", ROM0[$0150]

Start:
    ; Turn off the LCD (required before modifying video memory)
    ld a, 0             ; Load 0 into register A
    ld [$FF40], a       ; Store to LCD Control register (turns off screen)

    ; Clear ALL of VRAM to remove Nintendo logo
    ld hl, $8000        ; Start of VRAM
    ld bc, $2000        ; Clear 8KB (all VRAM: $8000-$9FFF)
    ld a, 0             ; Fill with zeros
    call FillMemory     ; Clear VRAM
    
    ; Clear OAM (sprite memory) to remove Nintendo logo sprites
    ld hl, $FE00        ; Start of OAM (sprite memory)
    ld bc, $00A0        ; Clear 160 bytes (40 sprites × 4 bytes each)
    ld a, 0             ; Fill with zeros
    call FillMemory     ; Clear all sprites

    ; Clear Nintendo logo tilemap area specifically
    ld hl, $9900        ; Start of Nintendo logo tilemap area  
    ld bc, $0060        ; Clear 96 bytes 
    ld a, 0             ; Fill with zeros
    call FillMemory     ; Clear Nintendo logo tilemap

    ; Set up background palette (brown horse colors)
    ld a, %11100100     ; Palette: 11=dark brown, 10=med brown, 01=light brown, 00=white
    ld [$FF47], a       ; Store to Background Palette register

    ; Initialize with horse facing down
    ld a, 0             ; Direction 0 = down
    ld [CurrentDirection], a
    call LoadCurrentHorse

    ; Clear background tilemap
    ld hl, $9800        ; Start of background tilemap
    ld bc, $0400        ; Clear entire 32x32 tilemap  
    ld a, 0             ; Fill with tile 0 (blank)
    call FillMemory

    ; Display the horse (6x6 tiles starting at screen position 5,5)
    call DisplayHorse

    ; Turn the LCD back on with background enabled
    ld a, $91           ; $91 = LCD on, BG on, sprites off (for now)
    ld [$FF40], a       ; Store to LCD Control register (turns on screen)

    ; Main game loop with input checking
MainLoop:
    call CheckInput     ; Check for D-pad input
    halt                ; Halt CPU until next interrupt (saves power)
    jr MainLoop         ; Repeat forever

; ================================  
; UTILITY FUNCTIONS
; ================================
; Copy BC bytes from HL to DE
CopyMemory:
    ld a, [hl+]         ; Load byte from [HL], increment HL
    ld [de], a          ; Store byte to [DE]
    inc de              ; Increment DE
    dec bc              ; Decrement counter
    ld a, b             ; Check if BC = 0
    or c                
    jr nz, CopyMemory   ; If not zero, continue
    ret                 ; Return to caller

; Fill BC bytes starting at HL with value in A
FillMemory:
    push af               ; Save the fill value on the stack
FillLoop:
    pop af
    push af
    ld [hl+], a         ; Store A to [HL], increment HL
    dec bc              ; Decrement counter
    ld a, b             ; Check if BC = 0
    or c
    jr nz, FillLoop   ; If not zero, continue
    pop af
    ret                 ; Return to caller

; Load current horse tiles into VRAM based on CurrentDirection
LoadCurrentHorse:
    ld a, [CurrentDirection]
    
    ; Jump to appropriate horse data based on direction
    cp 0
    jr z, LoadHorseDown
    cp 1  
    jr z, LoadHorseLeft
    cp 2
    jr z, LoadHorseRight
    ; Otherwise load up (direction 3)
    
LoadHorseUp:
    ld hl, HorseUpTiles
    ld bc, HorseUpTilesEnd - HorseUpTiles
    jr LoadHorseData
    
LoadHorseDown:
    ld hl, HorseDownTiles
    ld bc, HorseDownTilesEnd - HorseDownTiles
    jr LoadHorseData
    
LoadHorseLeft:
    ld hl, HorseLeftTiles
    ld bc, HorseLeftTilesEnd - HorseLeftTiles
    jr LoadHorseData
    
LoadHorseRight:
    ld hl, HorseRightTiles  
    ld bc, HorseRightTilesEnd - HorseRightTiles
    
LoadHorseData:
    ld de, $8000        ; Load tiles starting at VRAM tile 0
    call CopyMemory     ; Copy horse tiles to VRAM
    ret