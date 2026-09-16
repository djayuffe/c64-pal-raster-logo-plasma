# DeepSeek C64 Ultimate PAL

IRQ-free PAL C64 demo with frame-synchronised raster sections, sprites,
scroller, logo effects, plasma colors, and generated charset decoration.

## Build

Requires ACME 0.97 or newer:

```sh
make
```

The output is `build/deepseek_c64_ultimate_pal.prg`. Run it with:

```sh
x64sc -autostart build/deepseek_c64_ultimate_pal.prg
```

## Repository layout

- `deepseek_c64_ultimate_pal.s` — corrected source.
- `Makefile` — strict ACME build and clean targets.
- `AUDIT.md` — repairs, design constraints, and validation.
- `SHA256SUMS.txt` — checksums for tracked files.

## Audit summary

Sprite phase indexing, logo color-pointer corruption, and raster carry leakage
were repaired while preserving the no-IRQ design and `SYS 4096` entry point.
