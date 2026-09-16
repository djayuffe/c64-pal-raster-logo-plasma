# C64 - PAL Raster Logo Plasma

![C64 effect preview](docs/preview.png)

Visual preview asset for this effect; run the VICE command below for an emulator capture.

IRQ-free PAL C64 demo with frame-synchronised raster sections, sprites,
scroller, logo effects, plasma colors, and generated charset decoration.

## Build

Requires ACME 0.97 or newer:

```sh
make
```

The output is `build/c64_pal_raster_logo_plasma.prg`. Run it with:

```sh
x64sc -autostart build/c64_pal_raster_logo_plasma.prg
```

## Repository layout

- `c64_pal_raster_logo_plasma.s` — corrected source.
- `Makefile` — strict ACME build and clean targets.
- `AUDIT.md` — repairs, design constraints, and validation.
- `SHA256SUMS.txt` — checksums for tracked files.

## Audit summary

Sprite phase indexing, logo color-pointer corruption, and raster carry leakage
were repaired while preserving the no-IRQ design and `SYS 4096` entry point.
## Documentation and license

Function-level documentation is in docs/FUNCTIONS.md. The project is released
under GPL-3.0; see LICENSE.
