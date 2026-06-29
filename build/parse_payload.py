import struct, sys

PAYLOAD = r"C:\Users\Kake\Documents\adb\ota_c1-11-customer_2022.521.8\payload.bin"

f = open(PAYLOAD, "rb")
magic = f.read(4)
assert magic == b"CrAU", magic
major = struct.unpack(">Q", f.read(8))[0]
manifest_size = struct.unpack(">Q", f.read(8))[0]
meta_sig_size = 0
if major >= 2:
    meta_sig_size = struct.unpack(">I", f.read(4))[0]
manifest = f.read(manifest_size)
print(f"major={major} manifest_size={manifest_size} meta_sig_size={meta_sig_size}")

# --- minimal protobuf wire reader ---
def read_varint(b, i):
    shift = 0; val = 0
    while True:
        c = b[i]; i += 1
        val |= (c & 0x7f) << shift
        if not (c & 0x80): break
        shift += 7
    return val, i

def parse(b):
    """yield (field_num, wire_type, value) ; value is int (varint) or bytes (len-delim)"""
    i = 0; out = []
    while i < len(b):
        key, i = read_varint(b, i)
        fn = key >> 3; wt = key & 7
        if wt == 0:
            v, i = read_varint(b, i)
        elif wt == 2:
            ln, i = read_varint(b, i)
            v = b[i:i+ln]; i += ln
        elif wt == 5:
            v = struct.unpack("<I", b[i:i+4])[0]; i += 4
        elif wt == 1:
            v = struct.unpack("<Q", b[i:i+8])[0]; i += 8
        else:
            raise ValueError(f"wt {wt}")
        out.append((fn, wt, v))
    return out

top = parse(manifest)

# show which top-level fields exist
from collections import Counter
print("top-level fields present:", dict(Counter(fn for fn,_,_ in top)))

# field 3 = block_size
for fn, wt, v in top:
    if fn == 3:
        print("block_size =", v)

# field 13 = repeated PartitionUpdate ; partition_name=1, new_partition_info=9 (size=1)
print("\n== partitions (field 13) ==")
parts = {}
for fn, wt, v in top:
    if fn == 13 and wt == 2:
        pu = parse(v)
        name = None; size = None
        for f2, w2, v2 in pu:
            if f2 == 1 and w2 == 2:
                name = v2.decode(errors="replace")
            if f2 == 7 and w2 == 2:  # PartitionInfo new_partition_info
                pi = parse(v2)
                for f3, w3, v3 in pi:
                    if f3 == 1 and w3 == 0:
                        size = v3
        parts[name] = size
        print(f"  {name:14} size={size}")

# field 14 = DynamicPartitionMetadata
print("\n== dynamic_partition_metadata (field 14) ==")
for fn, wt, v in top:
    if fn == 14 and wt == 2:
        dpm = parse(v)
        print("  raw subfields:", [(f2,w2,(v2 if w2==0 else (v2[:40] if isinstance(v2,bytes) else v2))) for f2,w2,v2 in dpm])
        for f2, w2, v2 in dpm:
            if w2 == 2:
                try:
                    print(f"   field {f2} nested:", [(a,b,(c if b==0 else (c[:60] if isinstance(c,bytes) else c))) for a,b,c in parse(v2)])
                except Exception as e:
                    print(f"   field {f2} bytes:", v2[:60])
        for f2, w2, v2 in dpm:
            if f2 == 1 and w2 == 2:  # group
                g = parse(v2)
                gname=None; gsize=None; gparts=[]
                for f3,w3,v3 in g:
                    if f3==1 and w3==2: gname=v3.decode(errors="replace")
                    if f3==2 and w3==0: gsize=v3
                    if f3==3 and w3==2: gparts.append(v3.decode(errors="replace"))
                print(f"  GROUP name={gname} size={gsize}")
                print(f"        partitions={gparts}")
            if f2 == 2 and w2 == 0:
                print("  snapshot_enabled =", v2)
            if f2 == 3 and w2 == 0:
                print("  vabc_enabled =", v2)
