import struct, sys

# Partially unsparse an Android sparse image, writing at most MAXOUT bytes
# (enough to cover the liblp geometry+metadata region near the start).
src = sys.argv[1]
dst = sys.argv[2]
MAXOUT = int(sys.argv[3]) if len(sys.argv) > 3 else (32*1024*1024)

f = open(src, "rb")
hdr = f.read(28)
magic, major, minor, fhdr, chdr, blk, total_blk, total_chunks, crc = struct.unpack("<IHHHHIIII", hdr)
assert magic == 0xed26ff3a, hex(magic)
if fhdr > 28:
    f.read(fhdr-28)
out = open(dst, "wb")
written = 0
for _ in range(total_chunks):
    ch = f.read(chdr)
    ctype, _r, csz, tsz = struct.unpack("<HHII", ch[:12])
    data_sz = tsz - chdr
    if ctype == 0xCAC1:      # RAW
        data = f.read(data_sz)
        out.write(data); written += len(data)
    elif ctype == 0xCAC2:    # FILL
        fill = f.read(4)
        out.write(fill * (csz * blk // 4)); written += csz*blk
    elif ctype == 0xCAC3:    # DONT_CARE
        out.write(b"\x00" * (csz*blk)); written += csz*blk
    elif ctype == 0xCAC4:    # CRC32
        f.read(4)
    if written >= MAXOUT:
        break
out.close()
print(f"wrote {written} bytes to {dst}")
