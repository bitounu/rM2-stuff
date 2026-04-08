# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Host (desktop emulation, tests enabled, clang, coverage):
cmake --preset dev-host
cmake --build build/dev-host

# Cross-compile for reMarkable (rM toolchain):
cmake --preset dev        # debug
cmake --preset release    # MinSizeRel

# Toltec toolchain:
cmake --preset dev-toltec
cmake --preset release-toltec

# Build a single target:
cmake --build build/dev-host --target yaft

# Run unit tests (dev-host preset enables BUILD_TESTS):
ctest --test-dir build/dev-host

# Run a single test binary directly:
./build/dev-host/test/unit/unit-tests "[TestName]"

# Package (ipk):
cmake --build build/dev --target package

# Lint (clang-tidy, treats warnings as errors):
cmake --preset dev-tidy
cmake --build build/dev-tidy
```

## Architecture Overview

### Libraries (`libs/`)

- **rMlib** — Core library for all rM apps. Provides framebuffer access, input handling (evdev), drawing canvas, and a declarative Flutter-inspired UI framework (`include/UI/`). When `EMULATE=ON`, swaps in SDL-based framebuffer/input backends.
- **unistdpp** — Thin C++ wrappers around UNIX syscalls (files, pipes, sockets, mmap, poll). Uses `tl::expected` for error handling throughout—this is the project-wide error handling pattern.
- **rm2fb** — Framebuffer interception library. Hooks xochitl's image-update functions at the binary level (no Qt dependency). Runs as a daemon (`ServerExe`) that apps connect to via UNIX stream socket. Apps link the client (`Client.cpp`) which speaks `Message.h` protocol. `PreloadHooks.cpp` / `ImageHook.cpp` intercept the actual xochitl calls.
- **swtcon** — Reverse-engineered software TCON; launched as `LD_PRELOAD` attached to xochitl.

### Apps (`apps/`)

- **yaft** — Framebuffer terminal emulator (forked from uobikiemukot/yaft). Uses rMlib for input/display. Config changes watched via inotify.
- **rocket** — Power-button-activated app launcher. Connects to kernel input device, floods keyboard on connect.
- **tilem** — TI-84+ calculator emulator.

### Tests (`test/`)

- `test/unit/` — Catch2 unit tests covering rMlib, yaft, rocket, tilem, unistdpp. Enabled only when `BUILD_TESTS=ON` (automatic with `dev-host` preset).
- `test/integration/` — Shell-based integration test (`test.sh`) using a `xochitl.toml` config.

### Cross-compilation

The default target is reMarkable 2 (ARMv7 HF). `cmake/rm-toolchain.cmake` points to the rM SDK. The toltec toolchain is an alternative cross-compiler. Desktop builds (`dev-host`) use the host compiler with `EMULATE=ON` which substitutes SDL for the actual display hardware and optionally uinput for input devices.

### Error handling

All system calls use `tl::expected<T, unistdpp::Error>` return types (from `unistdpp`). Avoid `errno`-style error checking—use the wrappers in `unistdpp`.
