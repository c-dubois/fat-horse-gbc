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
; TILE DATA - Our graphics!
; ================================

SECTION "Tile Data", ROM0

; Tile 0: Blank Tile (all color 0 - transparent/background)
BlankTile:
    db $00, $00    ; Row 0: all pixels = color 0 (low bits, high bits)
    db $00, $00    ; Row 1: all pixels = color 0
    db $00, $00    ; Row 2: all pixels = color 0
    db $00, $00    ; Row 3: all pixels = color 0
    db $00, $00    ; Row 4: all pixels = color 0
    db $00, $00    ; Row 5: all pixels = color 0
    db $00, $00    ; Row 6: all pixels = color 0
    db $00, $00    ; Row 7: all pixels = color 0

; Tile 1: Test pattern - 2x2 black square in top-left
TestTile:
    db $0F, $0F    ; Row 0: bits 11110000 = 4 black pixels, 4 background  
    db $F0, $F0    ; Row 1: bits 11110000 = 4 black pixels, 4 background
    db $F0, $F0    ; Row 2: bits 11110000 = 4 black pixels, 4 background
    db $F0, $F0    ; Row 3: bits 11110000 = 4 black pixels, 4 background
    db $00, $00    ; Row 4: all background pixels
    db $00, $00    ; Row 5: all background pixels  
    db $00, $00    ; Row 6: all background pixels
    db $00, $00    ; Row 7: all background pixels

; ================================
; MAIN PROGRAM
; ================================

SECTION "Main", ROM0[$0150]

Start:
    ; Turn off the LCD (required before modifying video memory)
    ld a, 0             ; Load 0 into register A
    ld [$FF40], a       ; Store to LCD Control register (turns off screen)

    ; Copy our tile data into VRAM (Video Ram)
    ld hl, BlankTile    ; Source: our tile data
    ld de, $8000        ; Destination: VRAM tile data area  
    ld bc, 32           ; Copy 32 bytes (2 tiles × 16 bytes each)
    call CopyMemory     ; Copy tiles to VRAM

    ; Clear the background tilemap (make screen blank)
    ld hl, $9800        ; HL points to start of background tilemap
    ld bc, $0400        ; BC = 1024 bytes (32×32 background map)
    ld a, 0             ; A = tile number 0 (blank tile)
    call FillMemory     ; Fill background with blank tiles

    ; Put our test tile in the top-left corner
    ld a, 1             ; Tile number 1 (our test pattern)
    ld [$9800], a       ; Store at background map position 0,0

    ; Turn the LCD back on with background enabled
    ld a, $91           ; $91 = LCD on, BG on, sprites off (for now)
    ld [$FF40], a       ; Store to LCD Control register (turns on screen)

    ; Infinite loop - our "game" shows the test pattern
MainLoop:
    halt                ; Halt CPU until next interrupt (saves power)
    jr MainLoop         ; Jump back to halt again - repeat forever

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

; Fill BC bytes startin gat HL with value in A
FillMemory:
    push af               ; Save the fill value on the stack
FillLoop:
    pop af
    push af
    ld [hl+], a         ; Store A to [HL], increment HL
    dec bc              ; Decrement counter
    ld d, b             ; Check if BC = 0
    or c
    jr nz, FillLoop   ; If not zero, continue
    pop af
    ret                 ; Return to caller