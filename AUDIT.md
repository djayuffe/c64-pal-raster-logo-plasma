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
`ade21d4f5af51ad2182053335acaeed6c7caac648f27e01ac9482fc7f8080c86`.
