# Function reference

This is the PAL frame-synchronised raster/logo/plasma effect.

| Function | Responsibility |
|---|---|
| MainLoop / WaitFrameStart | Synchronizes each frame without installing IRQs. |
| TopSection / MidSection | Runs the timed raster sections. |
| UpdateScroll / UpdateSprites | Advances the message and sprite phases. |
| ColorWaveEffect / PlasmaEffect | Generates animated palette effects. |
| RasterBars | Produces the raster-bar color sequence. |
| DrawLogo / LogoShine | Draws the logo and its highlight. |
| InstallCustomFont / BuildLogoFont | Installs and prepares the custom font. |

The no-IRQ design and SYS 4096 entry contract are intentional.
