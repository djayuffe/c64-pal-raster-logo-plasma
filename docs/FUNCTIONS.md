# Function reference

## Execution contract

The PRG contains a BASIC stub that calls `SYS 4096`; `Start` is the first
runtime label at `$1000`. It deliberately executes `SEI`, disables CIA and
VIC interrupts, acknowledges pending VIC flags, and never executes `CLI`.
`NMIStub` is an immediate `RTI`, making RESTORE harmless while the program owns
the raster-polling loop.

## Per-frame schedule

| Raster point | Routine | Actual work |
| --- | --- | --- |
| frame wrap / 0 | `WaitFrameStart`, `UpdateScroll` | Wait for a clean raster-0 edge, advance fine scroll or shift the bottom row. |
| 50 | `TopSection` | Change border colour from `RainbowBar`; animate the two logo colour rows. |
| 120 | `MidSection` | Position/configure all eight sprites and fill the visible colour-wave glyph field on rows 5–15. |
| 170 | `PlasmaEffect` | Cycle the background colour through `PlasmaColors`. |
| 220 | `RasterBars` | Emit a short timed border colour sequence from `Ice16`. |

`WaitRasterA` is defensive: when a target line has already passed, it waits for
the next frame before waiting again. This avoids an accidental long stall.

## Display routines

| Routine | Responsibility |
| --- | --- |
| `UpdateScroll` | Uses `$d016` fine X scroll for eight substeps, shifts screen/colour row 22, appends a looping screen-code message, and gives new glyphs a Fire16 colour. |
| `UpdateSprites` | Enables the eight VIC hardware sprites, derives X/Y from `Sine256` and `SpritePhase8`, cycles shared multicolour registers, and phase-toggles expansion. It does not multiplex sprites. |
| `ColorWaveEffect` | Writes the custom `$40` glyph and a 40-column colour wave across rows 5–15, offsetting each row by three palette steps. |
| `PlasmaEffect` | Advances one background-colour phase per frame. |
| `RasterBars` | Produces 20 brief border writes after raster 220, then restores the blue border. |
| `DrawLogo` / `LogoShine` | Center and draw the two logo strings with shadow rows, then cycle their colour RAM entries independently. |
| `DrawBorders` | Places the custom decoration glyph along the top and lower separator rows. |

## Asset and VIC setup

`CopyROMCharset` exposes character ROM with `$01=$33`, copies 2 KB to `$2000`,
and restores the original processor-port value. `InstallCustomFont` boldens the
copied glyphs in place. `BuildLogoFont` also creates a horizontal/vertical
smear variant at `$3000`; the safe build keeps `$2000` selected. `CreateSpriteData`
builds one 64-byte sprite shape at `$2800` and copies it to all eight sprite
slots.

The active layout is VIC bank 0, screen `$0400`, colour RAM `$d800`, charset
`$2000`, and `$d018=$18`; `SetCharBase3000` remains a documented but unused
safe-build helper. The no-IRQ design and `SYS 4096` entry contract are
intentional.
