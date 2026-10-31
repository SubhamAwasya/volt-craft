#!/usr/bin/env bash
set -e

SRC_PNG="${1:-voltcraft/AppIcon.png}"
OUT_DIR="voltcraft/AppIcon.iconset"
OUT_ICNS="voltcraft/AppIcon.icns"

if [ ! -f "$SRC_PNG" ]; then
    echo "Error: Source image $SRC_PNG not found."
    exit 1
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "Generating iconset resolutions from $SRC_PNG..."
sips -z 16 16     "$SRC_PNG" --out "$OUT_DIR/icon_16x16.png" >/dev/null
sips -z 32 32     "$SRC_PNG" --out "$OUT_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$SRC_PNG" --out "$OUT_DIR/icon_32x32.png" >/dev/null
sips -z 64 64     "$SRC_PNG" --out "$OUT_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$SRC_PNG" --out "$OUT_DIR/icon_128x128.png" >/dev/null
sips -z 256 256   "$SRC_PNG" --out "$OUT_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$SRC_PNG" --out "$OUT_DIR/icon_256x256.png" >/dev/null
sips -z 512 512   "$SRC_PNG" --out "$OUT_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$SRC_PNG" --out "$OUT_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$SRC_PNG" --out "$OUT_DIR/icon_512x512@2x.png" >/dev/null

echo "Converting iconset to $OUT_ICNS..."
iconutil -c icns "$OUT_DIR" -o "$OUT_ICNS"
rm -rf "$OUT_DIR"

echo "Created $OUT_ICNS successfully!"
