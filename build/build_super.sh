#!/bin/bash
# Rebuild super_built.img from the 5 genuine A11 logical-partition images.
#
# Prereq: extract these from ota_c1-11-customer_2022.521.8.zip (payload.bin) with
# payload-dumper and place them in build/src/ :
#   system.img system_ext.img product.img vendor.img odm.img
#
# Geometry below is authoritative - read from the OTA payload manifest
# (see parse_payload.py) and cross-checked against the real device (getvar).
#
# Run via WSL, e.g.:  wsl -d Ubuntu bash build/build_super.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
LP="$HERE/../bin/lpmake"
SRC="$HERE/src"
OUT="$HERE/../super_built.img"
G=surface_dynamic_partitions_a

chmod +x "$LP" 2>/dev/null || true

"$LP" \
  --metadata-size 65536 \
  --metadata-slots 2 \
  --super-name super \
  --device super:15032385536 \
  --group ${G}:7511998464 \
  --partition system_a:readonly:1124737024:${G}     --image system_a="$SRC/system.img" \
  --partition system_ext_a:readonly:215367680:${G}  --image system_ext_a="$SRC/system_ext.img" \
  --partition product_a:readonly:3720089600:${G}    --image product_a="$SRC/product.img" \
  --partition vendor_a:readonly:1637969920:${G}     --image vendor_a="$SRC/vendor.img" \
  --partition odm_a:readonly:1224704:${G}           --image odm_a="$SRC/odm.img" \
  --sparse \
  --output "$OUT"

echo "built: $OUT"
ls -l "$OUT"
