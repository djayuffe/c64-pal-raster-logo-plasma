# Development and release guide

Copyright (C) 2026 Ulf Bertilsson. SPDX-License-Identifier: GPL-3.0-only.

## Toolchain

The build needs ACME 0.97 or newer. Python 3 is needed for static validation
of the VICE capture utility. VICE `x64sc` 3.6 or newer is only required for
`make capture`.

```sh
make
shasum -a 256 -c SHA256SUMS.txt
python3 -B -c 'import ast, pathlib; ast.parse(pathlib.Path("tools/capture_vice.py").read_text())'
```

`make` assembles the PRG with `--strict-segments`; the generated binary must
remain at `build/c64_pal_raster_logo_plasma.prg`. The checksum manifest is part
of the release contract: update it whenever a tracked release file changes.

## Runtime contract

- The BASIC stub executes `SYS 4096`; `Start` must remain first at `$1000`.
- The active VIC layout is bank 0, screen `$0400`, colour RAM `$d800`, charset
  `$2000`, and `$d018=$18`.
- The demo deliberately uses `SEI`, disables CIA/VIC IRQs, and polls the raster
  instead of installing an IRQ handler.
- Keep target raster waits below 256 and preserve the `WaitRasterA` missed-line
  handling when changing the schedule.
- VICE captures are evidence of runtime output, not golden image tests; their
  instantaneous animation phase can differ after regeneration.

## CI pipelines

`.github/workflows/ci.yml` runs for pull requests, pushes to `main`, version
tags, and manual dispatch. It installs ACME, performs a clean strict build,
verifies `SHA256SUMS.txt`, syntax-checks the capture tool without cache writes,
and uploads the PRG
as an artifact.

`.github/workflows/release-verify.yml` runs when a GitHub release is published.
It repeats the release checks from the tagged source and uploads the verified
PRG as a workflow artifact, providing an independent release record.

## Release checklist

1. Update `VERSION` and `CHANGELOG.md`.
2. Run the three local validation commands above.
3. Review `git diff --check` and ensure every tracked file is represented in
   `SHA256SUMS.txt`.
4. Commit the release preparation, create an annotated `vX.Y.Z` tag, and push
   both branch and tag.
5. Publish a GitHub release from that tag with the PRG and `SHA256SUMS.txt` as
   assets. GitHub then runs the release-verification workflow.
