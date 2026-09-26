# Audit record

The source assembled, but runtime review found that sprite phase indexing used
VIC register offsets as indices into an eight-entry phase table. Logo color
writes also overwrote the pointer high byte with the loop index, and the
raster-bar phase leaked carry between additions.

Repairs:

- preserve a separate sprite index and compute register offsets explicitly;
- use a dedicated zero-page scratch byte for logo loop state;
- clear carry before the second raster-bar addition.

Validation: ACME `--strict-segments` succeeds; the no-IRQ frame-polling design
and `SYS 4096` entry contract are unchanged. Corrected build SHA-256:
`9bc27e36ce28905ad567b74bd99504ec14196bb919371587bce8a707b7e2f370`.

The repository additionally includes reproducible VICE framebuffer capture in
`tools/capture_vice.py`. The two tracked 320×200 runtime frames are captured
through the PRG's `SYS 4096` boot path; the separate concept-art image is
explicitly labelled as non-runtime artwork.
