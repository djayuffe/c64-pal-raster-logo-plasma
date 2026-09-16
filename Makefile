.PHONY: all clean

ACME ?= acme
OUTPUT := build/deepseek_c64_ultimate_pal.prg
SOURCE := deepseek_c64_ultimate_pal.s

all: $(OUTPUT)

$(OUTPUT): $(SOURCE)
	@mkdir -p build
	$(ACME) --strict-segments -f cbm -o $@ $(SOURCE)

clean:
	rm -rf build
