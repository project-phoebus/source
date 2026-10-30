#!/usr/bin/env python3
"""An SR10.2 domain_os image file, read by virtual address through its
link map's `loaded at' sections (tools/asm_compare.py --image)."""

import re

RFC_LOAD = 0x101400     # the RFC image's load address (file offset 0)


class Image:
    """The SR10.2 SAU2 image file, read by virtual address through the
    map's `loaded at' sections."""

    # fixed columns: kind, a 2-column section number, an 8-column address
    # (the SAU6..9 maps run an 8-digit address into the section number)
    SEC_RE = re.compile(r'^([ID])([ \d]{2})([ 0-9A-F]{8})\s+(\S+)\s+loaded at '
                        r'([0-9A-F]+),\s*size = ([0-9A-F]+)')

    def __init__(self, map_path, image_path):
        with open(image_path, 'rb') as f:
            self.data = f.read()
        # the RFC header's load address (file offset 0): 0x101400 on the
        # SAU2, SAU3, SAU5; other SAUs load elsewhere
        load = int.from_bytes(self.data[0:4], 'big') or RFC_LOAD
        self.secs = []          # (va, size, file offset)
        with open(map_path, encoding='latin-1') as f:
            for line in f:
                m = self.SEC_RE.match(line)
                if not m:
                    continue
                va, lat, size = (int(m.group(3), 16), int(m.group(5), 16),
                                 int(m.group(6), 16))
                if size and lat >= load:
                    self.secs.append((va, size, lat - load))

    def read(self, va, n):
        """The image's n bytes at va, or None if not all of them are in the
        file (the image's bss, past RELOC, has no bytes)."""
        best = None
        for sva, size, off in self.secs:
            if sva <= va and va + n <= sva + size:
                if best is None or size < best[1]:
                    best = (sva, size, off)
        if best is None:
            return None
        o = best[2] + (va - best[0])
        if o + n > len(self.data):
            return None
        return self.data[o:o + n]
