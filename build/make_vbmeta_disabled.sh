#!/bin/bash
# Produce images/vbmeta_disabled.img : stock vbmeta with dm-verity AND AVB
# verification turned off. We set the AvbVBMetaImageHeader.flags field (big-endian
# uint32 at offset 0x78) to 0x00000003:
#   bit0 = HASHTREE_DISABLED (dm-verity off)
#   bit1 = VERIFICATION_DISABLED (whole AVB chain off)
# On an UNLOCKED device the now-invalid signature is ignored, so this boots a
# super whose hashes don't match stock vbmeta (e.g. a rebuilt super).
set -e
SRC="${1:-images/vbmeta.img}"          # stock vbmeta
DST="${2:-images/vbmeta_disabled.img}"
cp "$SRC" "$DST"
printf '\x03' | dd of="$DST" bs=1 seek=123 count=1 conv=notrunc 2>/dev/null
echo "flags @0x78 now:"; xxd -s 0x78 -l 8 "$DST"
echo "magic still AVB0:"; xxd -l 4 "$DST"
