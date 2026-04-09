# Yaft Larger Font (24×48) Design

## Goal

Replace the hardcoded 16×32 bitmap font in yaft with a 24×48 Terminus font, cross-compile for the reMarkable 2, and deploy via SSH.

## Background

Glyphs are stored in `vendor/libYaft/glyph.h` as two C arrays:
- `glyphs[]` — regular glyphs
- `bold_glyphs[]` — bold variants

`CELL_WIDTH` and `CELL_HEIGHT` constants in that file control the cell size used throughout `terminal.cpp` and `screen.cpp`.

The upstream yaft `mkfont_bdf` tool generates a `glyph.h` from any BDF font, but only outputs `glyphs[]`. The rM2-stuff `terminal.cpp` also references `bold_glyphs[]`, causing a compile failure without it. The fix is an empty stub — `terminal.cpp` already falls back to the regular glyph when bold lookup returns null.

## Font

**Terminus 24×48** (`ter-u24n.bdf`) from the `terminus-font` Arch package.
Result: 58 columns × 39 rows on the rM2 1404×1872 screen (vs 87×58 at 16×32).

## Steps

1. Install `terminus-font` on the host (provides BDF files at `/usr/share/fonts/misc/`)
2. Clone upstream yaft (`https://github.com/uobikiemukot/yaft`), build `mkfont_bdf`
3. Generate glyph.h: `./mkfont_bdf table/alias /usr/share/fonts/misc/ter-u24n.bdf > glyph.h`
4. Append empty bold stub: `echo 'static const struct glyph_t bold_glyphs[] = {};' >> glyph.h`
5. Replace `vendor/libYaft/glyph.h` in this repo with the generated file
6. Cross-compile: `cmake --preset dev && cmake --build build/dev --target yaft`
   - Requires rM SDK at `/opt/codex/rm2/5.0.58-dirty` (see https://remarkable.guide/devel/toolchains.html)
7. Deploy: `scp build/dev/apps/yaft/yaft root@10.11.99.1:/home/root/`
8. Test: `ssh remarkable 'LD_PRELOAD=/opt/lib/librm2fb_client.so.1.0.1 /home/root/yaft'`

## Toolchain

Cross-compiles to ARMv7 HF (Cortex-A7) using the reMarkable SDK. The `cmake/rm-toolchain.cmake` expects the SDK at `/opt/codex/rm2/5.0.58-dirty` or `$TOOLCHAIN_ROOT` env var override.
