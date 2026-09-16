.PHONY: all clean

ACME ?= acme
OUTPUT := build/c64_pal_raster_logo_plasma.prg
SOURCE := c64_pal_raster_logo_plasma.s

all: $(OUTPUT)

$(OUTPUT): $(SOURCE)
	@mkdir -p build
	$(ACME) --strict-segments -f cbm -o $@ $(SOURCE)

clean:
	rm -rf build
