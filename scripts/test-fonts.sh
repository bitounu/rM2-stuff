#!/usr/bin/env bash
# test-fonts.sh — Build yaft variants with different bitmap fonts for reMarkable 2.
#
# All fonts have Polish support (żółćęśąźń ŻÓŁĆĘŚĄŹŃ).
# Outputs: build/font-test/yaft-{name}
#
# Usage:
#   ./scripts/test-fonts.sh                      # build all variants
#   ./scripts/test-fonts.sh root@10.11.99.1      # build + scp each to device
#
# Test on device:
#   LD_PRELOAD=/opt/lib/librm2fb_client.so.1.0.1 /home/root/yaft-{name}
#   echo 'żółćęśąźń ŻÓŁĆĘŚĄŹŃ'   # Polish check
#
# Variants (rM2 screen = 1404×1872 px):
#   terminus-16x32   Terminus 16×32 — 87 cols × 58 rows  (original, reference)
#   terminus-24x48   Terminus 12×24 scaled 2×            — 58 cols × 39 rows  ★
#   terminus-28x56   Terminus 14×28 scaled 2×            — 50 cols × 33 rows
#   terminus-32x64   Terminus 16×32 scaled 2×            — 43 cols × 29 rows
#   spleen-16x32     Spleen 16×32                        — 87 cols × 58 rows
#   spleen-32x64     Spleen 32×64 (current on device)    — 43 cols × 29 rows

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FONTS_DIR="/tmp/yaft-fonts"
LIBEVDEV_CACHE="/tmp/toltec-libevdev"
BUILD_OUT="$REPO_DIR/build/font-test"
TOLTEC_EXTRA="/tmp/toltec-extra"
CROSS_INI="/tmp/toltec-cross.ini"
DOCKER_IMAGE="ghcr.io/toltec-dev/toolchain:v3.1"
DEVICE="${1:-}"
SSH_KEY="id_ed25519"

echo "REPO_DIR: $REPO_DIR"
echo "BUILD_OUT: $BUILD_OUT"

mkdir -p "$FONTS_DIR" "$BUILD_OUT" "$LIBEVDEV_CACHE"

# ─────────────────────────────────────────────────────────────────────────────
# Cross.ini for meson (written once)
# ─────────────────────────────────────────────────────────────────────────────
if [[ ! -f "$CROSS_INI" ]]; then
cat > "$CROSS_INI" << 'EOF'
[binaries]
c = 'arm-linux-gnueabihf-gcc'
ar = 'arm-linux-gnueabihf-ar'
strip = 'arm-linux-gnueabihf-strip'

[host_machine]
system = 'linux'
cpu_family = 'arm'
cpu = 'armv7'
endian = 'little'
EOF
fi

# ─────────────────────────────────────────────────────────────────────────────
# BDF 2× pixel scaler (Python, runs on host)
# Doubles each pixel horizontally and vertically: 12×24 → 24×48, etc.
# ─────────────────────────────────────────────────────────────────────────────
scale_bdf_2x() {
  local src="$1" dst="$2"
  [[ -f "$dst" ]] && return
  echo "  Scaling $(basename "$src") → $(basename "$dst")..."
  python3 - "$src" "$dst" << 'PYEOF'
import sys, re

def scale_row(hex_str: str, char_width: int) -> str:
    nbytes = (char_width + 7) // 8
    # parse hex and right-justify the actual char_width bits
    val = int(hex_str, 16) >> (nbytes * 8 - char_width)
    out = 0
    for i in range(char_width):
        bit = (val >> (char_width - 1 - i)) & 1
        out = (out << 2) | (bit * 3)      # each bit → 2 identical bits
    new_width = char_width * 2
    new_bytes = (new_width + 7) // 8
    out <<= (new_bytes * 8 - new_width)   # left-align
    return format(out, f'0{new_bytes * 2}X')

src, dst = sys.argv[1], sys.argv[2]
lines = open(src).readlines()
out = []
in_bitmap = False
char_width = 0

for line in lines:
    s = line.strip()
    if s.startswith('SIZE '):
        p = s.split()
        out.append(f'SIZE {int(p[1])*2} {p[2]} {p[3]}\n'); continue
    if s.startswith('FONT_ASCENT '):
        out.append(f'FONT_ASCENT {int(s.split()[1])*2}\n'); continue
    if s.startswith('FONT_DESCENT '):
        out.append(f'FONT_DESCENT {int(s.split()[1])*2}\n'); continue
    if s.startswith('FONTBOUNDINGBOX '):
        p = s.split(); w,h,ox,oy = int(p[1]),int(p[2]),int(p[3]),int(p[4])
        out.append(f'FONTBOUNDINGBOX {w*2} {h*2} {ox*2} {oy*2}\n'); continue
    if s.startswith('BBX '):
        p = s.split(); w,h,ox,oy = int(p[1]),int(p[2]),int(p[3]),int(p[4])
        char_width = w
        out.append(f'BBX {w*2} {h*2} {ox*2} {oy*2}\n'); continue
    if s.startswith('DWIDTH '):
        p = s.split(); out.append(f'DWIDTH {int(p[1])*2} {p[2]}\n'); continue
    if s == 'BITMAP':
        in_bitmap = True; out.append(line); continue
    if s == 'ENDCHAR':
        in_bitmap = False; out.append(line); continue
    if in_bitmap:
        scaled = scale_row(s, char_width)
        out.append(scaled + '\n')
        out.append(scaled + '\n')   # duplicate row for vertical 2×
        continue
    out.append(line)

open(dst, 'w').writelines(out)
print(f"  → {dst}")
PYEOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Download fonts (host)
# ─────────────────────────────────────────────────────────────────────────────
echo "=== Preparing fonts ==="

# Terminus tarball (Polish + many European scripts)
TERM_TAR="$FONTS_DIR/terminus-font.tar.gz"
if [[ ! -f "$TERM_TAR" ]]; then
  echo "  Downloading Terminus font..."
  curl -fsSL \
    "https://downloads.sourceforge.net/project/terminus-font/terminus-font-4.49/terminus-font-4.49.1.tar.gz" \
    -o "$TERM_TAR"
fi
for size in 24 28 32; do
  bdf="$FONTS_DIR/ter-u${size}n.bdf"
  [[ -f "$bdf" ]] || tar -xOf "$TERM_TAR" "terminus-font-4.49.1/ter-u${size}n.bdf" > "$bdf"
done

# Spleen (clean bitmap font, Latin Extended covers Polish)
for sz in 16x32 32x64; do
  bdf="$FONTS_DIR/spleen-${sz}.bdf"
  [[ -f "$bdf" ]] || {
    echo "  Downloading Spleen ${sz}..."
    curl -fsSL \
      "https://raw.githubusercontent.com/fcambus/spleen/master/spleen-${sz}.bdf" \
      -o "$bdf"
  }
done

# Scaled Terminus variants (intermediate sizes, Polish support)
scale_bdf_2x "$FONTS_DIR/ter-u24n.bdf" "$FONTS_DIR/terminus-24x48.bdf"
scale_bdf_2x "$FONTS_DIR/ter-u28n.bdf" "$FONTS_DIR/terminus-28x56.bdf"
scale_bdf_2x "$FONTS_DIR/ter-u32n.bdf" "$FONTS_DIR/terminus-32x64.bdf"

echo "  Fonts ready in $FONTS_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# Build libevdev.a once (ARM static, for toltec sysroot)
# ─────────────────────────────────────────────────────────────────────────────
if [[ ! -f "$LIBEVDEV_CACHE/lib/libevdev.a" ]]; then
  echo ""
  echo "=== Building libevdev (one-time, ARM static) ==="
  docker run --rm \
    -v "$LIBEVDEV_CACHE:/cache" \
    -v "$CROSS_INI:/tmp/cross.ini:ro" \
    "$DOCKER_IMAGE" bash -c '
set -e
curl -sL https://www.freedesktop.org/software/libevdev/libevdev-1.13.1.tar.xz -o /tmp/libevdev.tar.xz
tar -xf /tmp/libevdev.tar.xz -C /tmp
meson setup /tmp/libevdev-build /tmp/libevdev-1.13.1 \
  --cross-file /tmp/cross.ini \
  --prefix=/cache --libdir=/cache/lib \
  --default-library=static \
  -Dtests=disabled -Ddocumentation=disabled > /dev/null 2>&1
ninja -C /tmp/libevdev-build install -j4 > /dev/null 2>&1
cp /tmp/libevdev-build/meson-private/libevdev.pc /cache/lib/pkgconfig/ 2>/dev/null || true
echo "libevdev.a built"
'
  echo "  Cached to $LIBEVDEV_CACHE"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Clone yaft upstream (for mkfont_bdf) — done once on host
# ─────────────────────────────────────────────────────────────────────────────
YAFT_UPSTREAM="/tmp/yaft-upstream"
if [[ ! -f "$YAFT_UPSTREAM/mkfont_bdf" ]]; then
  echo ""
  echo "=== Building mkfont_bdf ==="
  [[ -d "$YAFT_UPSTREAM" ]] || git clone --quiet https://github.com/uobikiemukot/yaft "$YAFT_UPSTREAM"
  make -C "$YAFT_UPSTREAM" mkfont_bdf -s 2>/dev/null || make -C "$YAFT_UPSTREAM" -s 2>/dev/null
  [[ -f "$YAFT_UPSTREAM/mkfont_bdf" ]] && echo "  mkfont_bdf built" || echo "  WARNING: mkfont_bdf not found"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Build one yaft variant
# ─────────────────────────────────────────────────────────────────────────────
build_variant() {
  local name="$1" bdf="$2" note="$3"
  local out="$BUILD_OUT/yaft-${name}"

  if [[ ! -f "$bdf" ]]; then
    echo "  SKIP $name — BDF not found: $bdf"
    return
  fi

  echo ""
  echo "─── $name ─── $note"

  # Generate glyph.h on host
  # mkfont_bdf must run from yaft-upstream dir (reads ./table/ISO10646 relative to cwd)
  local glyph_h="$FONTS_DIR/glyph-${name}.h"
  if [[ ! -s "$glyph_h" ]]; then  # -s: non-empty file
    (cd "$YAFT_UPSTREAM" && ./mkfont_bdf ./table/alias "$bdf") 2>/dev/null \
      | grep -v '^>>WARN' > "$glyph_h"
    echo 'static const struct glyph_t bold_glyphs[] = {};' >> "$glyph_h"
    if [[ ! -s "$glyph_h" ]]; then
      echo "  ERROR: mkfont_bdf produced empty glyph.h for $name"
      return 1
    fi
    # Show detected cell size
    grep -o 'CELL_WIDTH = [0-9]*\|CELL_HEIGHT = [0-9]*' "$glyph_h" | tr '\n' ' '
    echo ""
  fi

  # Clean build dir on host first (it may be root-owned from a prior Docker run)
  sudo rm -rf "$REPO_DIR/build/dev-toltec-font"

  # Docker build (-i required so Docker connects stdin to container for heredoc)
  docker run --rm -i \
    -v "$REPO_DIR:/repo" \
    -v "$TOLTEC_EXTRA:/toltec-extra" \
    -v "$LIBEVDEV_CACHE:/libevdev-cache:ro" \
    -v "$glyph_h:/tmp/glyph.h:ro" \
    -v "$FONTS_DIR:/tmp/fonts-host:ro" \
    "$DOCKER_IMAGE" bash << 'DOCKEREOF'
set -euo pipefail
SYSROOT=/opt/x-tools/arm-remarkable-linux-gnueabihf/arm-remarkable-linux-gnueabihf/sysroot
BUILD_DIR=/repo/build/dev-toltec-font

# Install udev/systemd into sysroot
cp /toltec-extra/usr/include/libudev.h $SYSROOT/usr/include/
cp /toltec-extra/usr/lib/libudev.so* $SYSROOT/usr/lib/
cp /toltec-extra/usr/lib/pkgconfig/libudev.pc $SYSROOT/usr/lib/pkgconfig/ 2>/dev/null || true
cp /toltec-extra/usr/lib/pkgconfig/libsystemd.pc $SYSROOT/usr/lib/pkgconfig/ 2>/dev/null || true

# Install libevdev from cache
cp /libevdev-cache/lib/libevdev.a $SYSROOT/usr/lib/
cp -r /libevdev-cache/include/libevdev-1.0 $SYSROOT/usr/include/
# Install pkg-config file with sysroot-adjusted prefix
sed "s|^prefix=.*|prefix=$SYSROOT/usr|;s|/cache/lib|$SYSROOT/usr/lib|g;s|/cache/include|$SYSROOT/usr/include|g" \
  /libevdev-cache/lib/pkgconfig/libevdev.pc > $SYSROOT/usr/lib/pkgconfig/libevdev.pc

# Install font
cp /tmp/glyph.h /repo/vendor/libYaft/glyph.h

# Python xxd replacement
cat > /usr/bin/xxd << 'PYEOF'
#!/usr/bin/env python3
import sys, os
args = sys.argv[1:]
if "-i" in args:
    args.remove("-i")
    fname = args[0]; outfile = args[1] if len(args) > 1 else None
    varname = os.path.basename(fname).replace(".", "_").replace("-", "_")
    data = open(fname, "rb").read()
    out = [f"unsigned char {varname}[] = {{"]
    for i in range(0, len(data), 12):
        chunk = data[i:i+12]
        out.append("  " + ", ".join(f"0x{b:02x}" for b in chunk) + ("," if i+12 < len(data) else ""))
    out.extend(["};", f"unsigned int {varname}_len = {len(data)};", ""])
    content = "\n".join(out)
    if outfile:
        open(outfile, "w").write(content)
    else:
        print(content, end="")
else:
    sys.exit(1)
PYEOF
chmod +x /usr/bin/xxd

# Configure (build dir was already cleaned on host)
mkdir -p $BUILD_DIR/include
cp /repo/build/dev-host/include/noto-sans-mono.h $BUILD_DIR/include/ 2>/dev/null || true

export PKG_CONFIG_PATH=$SYSROOT/usr/lib/pkgconfig
cd /repo
cmake --preset dev-toltec \
  -DCMAKE_EXE_LINKER_FLAGS="-Wl,--allow-shlib-undefined" \
  -B $BUILD_DIR > /dev/null 2>&1

# Build (show last lines; fail on cmake error via pipefail)
cmake --build $BUILD_DIR --target yaft -j4 2>&1 | tail -5
ls $BUILD_DIR/apps/yaft/yaft
echo "  built: $(stat -c%s $BUILD_DIR/apps/yaft/yaft) bytes"
DOCKEREOF

  if [[ -f "$REPO_DIR/build/dev-toltec-font/apps/yaft/yaft" ]]; then
    cp "$REPO_DIR/build/dev-toltec-font/apps/yaft/yaft" "$out"
    echo "  ✓ $out ($(du -sh "$out" | cut -f1))"
    if [[ -n "$DEVICE" ]]; then
      scp -i /home/bitounu/.ssh/"$SSH_KEY" "$out" "${DEVICE}:/home/root/yaft-${name}"
      echo "  → Deployed to ${DEVICE}:/home/root/yaft-${name}"
    fi
  else
    echo "  ✗ Build failed"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Build all variants
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Building font variants ==="

build_variant "terminus-16x32" \
  "$FONTS_DIR/ter-u32n.bdf" \
  "87 cols × 58 rows (original size, reference)"

build_variant "terminus-24x48" \
  "$FONTS_DIR/terminus-24x48.bdf" \
  "58 cols × 39 rows ★ good starting point"

build_variant "terminus-28x56" \
  "$FONTS_DIR/terminus-28x56.bdf" \
  "50 cols × 33 rows"

build_variant "terminus-32x64" \
  "$FONTS_DIR/terminus-32x64.bdf" \
  "43 cols × 29 rows (Terminus glyphs at Spleen size)"

build_variant "spleen-16x32" \
  "$FONTS_DIR/spleen-16x32.bdf" \
  "87 cols × 58 rows (Spleen style)"

build_variant "spleen-32x64" \
  "$FONTS_DIR/spleen-32x64.bdf" \
  "43 cols × 29 rows (currently on device)"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Done ==="
echo ""
echo "Binaries:"
ls -lh "$BUILD_OUT"/yaft-* 2>/dev/null | awk '{print "  "$NF, $5}' || echo "  (none)"
echo ""
echo "Deploy manually:"
echo "  scp build/font-test/yaft-<name> root@10.11.99.1:/home/root/"
echo "  ssh root@10.11.99.1 'LD_PRELOAD=/opt/lib/librm2fb_client.so.1.0.1 /home/root/yaft-<name>'"
echo ""
echo "Polish test (inside yaft):  echo 'żółćęśąźń ŻÓŁĆĘŚĄŹŃ'"
