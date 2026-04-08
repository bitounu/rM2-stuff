#!/usr/bin/env bash
# setup-toltec-extra.sh — Populate /tmp/toltec-extra with libudev/libsystemd
# from the reMarkable SDK sysroot.
#
# Run this once after each reboot before building with the toltec toolchain.
# (Or set TOLTEC_EXTRA_DIR to a persistent location to avoid re-running.)
#
# Prerequisites: rM SDK at /opt/codex/rm2/5.0.58-dirty
# See: https://remarkable.guide/devel/toolchains.html

set -euo pipefail

RM_SYSROOT="${RM_SYSROOT:-/opt/codex/rm2/5.0.58-dirty/sysroots/cortexa7hf-neon-remarkable-linux-gnueabi}"
DEST="${TOLTEC_EXTRA_DIR:-/tmp/toltec-extra}"

# The toltec sysroot path inside Docker (fixed by the toolchain image)
TOLTEC_SYSROOT="/opt/x-tools/arm-remarkable-linux-gnueabihf/arm-remarkable-linux-gnueabihf/sysroot/usr"

if [[ ! -d "$RM_SYSROOT" ]]; then
  echo "ERROR: rM SDK sysroot not found at $RM_SYSROOT"
  echo "Install the SDK from https://remarkable.guide/devel/toolchains.html"
  echo "or set RM_SYSROOT=/path/to/sysroot"
  exit 1
fi

mkdir -p "$DEST/usr/lib/pkgconfig"
mkdir -p "$DEST/usr/include/systemd"

echo "Copying libudev..."
cp "$RM_SYSROOT/usr/lib/libudev.so"*   "$DEST/usr/lib/"
cp "$RM_SYSROOT/usr/include/libudev.h" "$DEST/usr/include/"

echo "Copying libsystemd..."
cp "$RM_SYSROOT/usr/lib/libsystemd.so"* "$DEST/usr/lib/" 2>/dev/null || true
cp "$RM_SYSROOT/usr/include/systemd/"*  "$DEST/usr/include/systemd/" 2>/dev/null || true

echo "Writing pkg-config files..."
cat > "$DEST/usr/lib/pkgconfig/libudev.pc" << EOF
prefix=$TOLTEC_SYSROOT
exec_prefix=$TOLTEC_SYSROOT
libdir=$TOLTEC_SYSROOT/lib
includedir=$TOLTEC_SYSROOT/include

Name: libudev
Description: libudev
Version: 255
Libs: -L\${libdir} -ludev
Cflags: -I\${includedir}
EOF

cat > "$DEST/usr/lib/pkgconfig/libsystemd.pc" << EOF
prefix=$TOLTEC_SYSROOT
exec_prefix=$TOLTEC_SYSROOT
libdir=$TOLTEC_SYSROOT/lib
includedir=$TOLTEC_SYSROOT/include

Name: libsystemd
Description: systemd Library
Version: 255
Libs: -L\${libdir} -lsystemd
Cflags: -I\${includedir}
EOF

echo "Done. Contents of $DEST:"
find "$DEST" -type f | sort | sed 's|^|  |'
