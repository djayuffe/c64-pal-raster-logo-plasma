.PHONY: all capture clean

ACME ?= acme
OUTPUT := build/c64_pal_raster_logo_plasma.prg
SOURCE := c64_pal_raster_logo_plasma.s

all: $(OUTPUT)

$(OUTPUT): $(SOURCE)
	@mkdir -p build
	$(ACME) --strict-segments -f cbm -o $@ $(SOURCE)

capture:
	python3 tools/capture_vice.py docs/runtime-plasma.png --seconds 2
	python3 tools/capture_vice.py docs/runtime-colour-wave.png --seconds 3
	python3 tools/capture_vice.py docs/runtime-raster-transition.png --seconds 4
	python3 tools/capture_vice.py docs/runtime-raster-bars.png --seconds 5
	python3 tools/capture_vice.py docs/runtime-scroller.png --seconds 6
	python3 tools/capture_vice.py docs/runtime-scroll-cycle.png --seconds 7

clean:
	rm -rf build
