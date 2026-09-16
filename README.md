# DeepSeek Ultimate Eye Candy PAL r7f

IRQ-free PAL C64 demo with frame-synchronised raster sections, sprites,
scroller, logo effects, plasma colors, and generated charset decoration.

## Build and run

```sh
acme --strict-segments -f cbm -o ultimate_demo.prg \
  deepseek_asm_20251009_ULTIMATE_EYECANDY_FINAL_PAL_r7f_SAFE_NOIRQ_SYS4096.s
x64sc -autostart ultimate_demo.prg
```

The audit repaired sprite phase indexing, color-pointer high-byte corruption,
and carry leakage in raster color arithmetic while preserving the no-IRQ
design. See `AUDIT.md`.
