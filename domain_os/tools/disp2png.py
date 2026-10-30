#!/usr/bin/env python3
"""disp2png.py - render a MAME boot's display dump as a PNG.

    tools/disp2png.py BOOT.LOG OUT.png

tools/mame_boot_direct.py --dump-display writes the DN300's display memory
(0x20000, 1024 x 800, one bit per pixel) as a "BOOT dump 00020000:" line of
hex words; this turns that line into a 1-bit grayscale PNG.
"""
import sys, re, zlib, struct
log = open(sys.argv[1], errors='replace').read()
line = next(l for l in log.split('\n') if 'BOOT dump 00020000:' in l)
toks = [t for t in line.split('00020000:', 1)[1].split() if re.fullmatch(r'[0-9a-fA-F]{4}', t)]
data = bytes.fromhex(''.join(toks))
W, H = 1024, 800
rows = b''.join(b'\x00' + bytes((~data[y*128+i]) & 0xFF for i in range(128)) for y in range(H))
def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 1, 0, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b'')
open(sys.argv[2], 'wb').write(png); print(len(data), 'bytes ->', sys.argv[2])
