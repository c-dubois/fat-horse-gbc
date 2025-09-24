# Fat Horse Game Boy Color Project
# Makefile for building ROM

# Project name
NAME = fat-horse

# Source files
SOURCES = main.asm

# Output files
ROM = $(NAME).gbc
MAP = $(NAME).map
SYM = $(NAME).sym

# Build the ROM
$(ROM): $(SOURCES)
	rgbasm -o main.o main.asm
	rgblink -o $(ROM) -m $(MAP) -n $(SYM) main.o
	rgbfix -v -p 0 $(ROM)

# Clean build files
clean:
	rm -f *.o $(ROM) $(MAP) $(SYM)

# Build and run in emulator
run: $(ROM)
	open -a SameBoy $(ROM)

.PHONY: clean run