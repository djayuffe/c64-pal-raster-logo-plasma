.PHONY: all clean

ACME ?= acme
OUTPUT := build/ultimate_demo.prg
SOURCE := deepseek_asm_20251009_ULTIMATE_EYECANDY_FINAL_PAL_r7f_SAFE_NOIRQ_SYS4096.s

all: $(OUTPUT)

$(OUTPUT): $(SOURCE)
	@mkdir -p build
	$(ACME) --strict-segments -f cbm -o $@ $(SOURCE)

clean:
	rm -rf build
