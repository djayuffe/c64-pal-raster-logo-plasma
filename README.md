# C64 - PAL Raster Logo Plasma

Copyright © 2026 Ulf Bertilsson. Licensed under [GPL-3.0](LICENSE); see
[NOTICE](NOTICE) for the project attribution.

## Live VICE captures

Each image is a direct 320×200 framebuffer capture from the compiled PRG.
They show distinct points in the continuously running effect rather than
separate screens or post-processed mockups.

### Booted logo and early colour-wave field

![Runtime plasma frame from VICE](docs/runtime-plasma.png)

The logo's Fire16/Ice16 colour shine is active while the `$40` custom glyph
begins filling the colour-wave rows below it.

### Full colour-wave field

![Wide live colour-wave field from VICE](docs/runtime-colour-wave.png)

Rows 5–15 are visibly filled with the custom glyph while their colour phase
advances independently by row, producing the wide horizontal wave.

### Raster transition

![Live raster transition from VICE](docs/runtime-raster-transition.png)

This frame catches the display as the later raster sections alter the active
palette: the logo remains stable while the field changes around it.

### Raster-bar burst

![Runtime raster-bar frame from VICE](docs/runtime-raster-bars.png)

Short, timed `Ice16` border writes occur after raster line 220, then restore
the blue border before the following frame.

### Scroller phase

![Runtime scroller frame from VICE](docs/runtime-scroller.png)

The bottom-row message moves one character per eight fine-scroll steps while
new characters receive cycling Fire16 colours.

### Later scroller palette state

![Later live scroller palette state from VICE](docs/runtime-scroll-cycle.png)

This later frame shows the same single continuous loop with a different plasma
and logo palette phase. The exact frame captured will naturally vary between
VICE runs because the demo is animated.

An IRQ-free, PAL-timed C64 demo written in 6502 assembly. It owns the frame
loop by polling the VIC raster counter, then switches visual sections at
raster lines 50, 120, 170, and 220. The result combines an animated two-line
logo, a hardware-sprite field, a colour-wave glyph field, a smooth bottom
scroller, plasma background cycling, and short border-bar bursts without installing a
raster IRQ handler.

The images above are reproducible 320×200 framebuffers captured from the
compiled PRG in VICE—not concept art or post-processed mockups.

## Build and run

Requires ACME 0.97 or newer:

```sh
make
x64sc -autostart build/c64_pal_raster_logo_plasma.prg
```

To recreate the documented runtime captures, install VICE `x64sc` 3.6 or
newer and run:

```sh
make capture
```

This builds the PRG, starts it through its BASIC `SYS 4096` entry point, and
writes the six live VICE framebuffers used above. Their capture delays range
from two to seven seconds, giving the gallery representative colour-wave,
raster, and scroller phases.

## Features

- **No-IRQ PAL frame loop:** `WaitFrameStart` waits for raster wrap at line 0;
  the program explicitly disables CIA and VIC IRQs and keeps them disabled.
- **Four raster-polled sections:** top-logo treatment begins at line 50,
  sprite and colour-wave work at 120, plasma colour cycling at 170, and
  border-bar pulses at 220.
- **Animated logo:** two centered logo rows have a moving Fire16 colour shine
  and a drop shadow drawn into screen and colour RAM.
- **Visible colour-wave field:** rows 5–15 are filled with the custom `$40`
  glyph while their palette phase advances independently by row.
- **Eight hardware sprites:** all VIC sprites follow sine-table positions,
  share cycling multicolour registers, and toggle X/Y expansion by phase.
  This is a single eight-sprite field, not a sprite multiplexer.
- **Fine-scroll message:** the bottom row advances at eight fine-scroll steps
  per character, loops a fixed screen-code message, and colours new glyphs
  from the Fire16 palette.
- **Generated display assets:** the ROM charset is copied to `$2000`, made
  bolder in place, then used for screen decoration and logo glyphs; sprite
  graphics are generated at `$2800`.
- **VIC layout:** bank 0, screen `$0400`, colour RAM `$d800`, and charset
  `$2000` with `$d018=$18` in standard 40-column text mode.

## Repository layout

- `c64_pal_raster_logo_plasma.s` — source and the `SYS 4096` entry point.
- `Makefile` — strict ACME build, capture, and clean targets.
- `tools/capture_vice.py` — reproducible VICE framebuffer capture helper.
- `docs/FUNCTIONS.md` — source-backed feature and routine reference.
- `AUDIT.md` — original correction record and design constraints.
- `SHA256SUMS.txt` — checksums for the complete tracked release set.

## Audit summary

Sprite phase indexing, logo colour-pointer corruption, and raster carry
leakage were repaired while preserving the no-IRQ design and `SYS 4096` entry
point. See [AUDIT.md](AUDIT.md) for the original correction record.

## Concept art

The original visual artwork is retained separately as
![concept art](docs/concept-art.png). It is inspiration only and is not
presented as demo output.
