#!/usr/bin/env python3
#
# tools/check_rfc.py - `make check-rfc': check the SAU2 RFC load image
# against the layout the loader expects, and dry-run the loader on it and
# on the original image; or another SAU's (--sau N), with that SAU's COLD
# addresses (the tables keyed by SAU below)
#
# Usage:
#   check_rfc.py [--sau N] --image dist/sau2/domain_os
#                --elf build/sau2/domain_os.elf
#                [--orig IMAGE --segments tools/rfc_segments.json
#                 [--ref tools/asm_image_ref.txt] [--map MAP]]
#
# The oracle (--orig and the files with it) is optional: the original
# image, the json tools/rfc_decode.py decodes from it (the SAU9's: this
# script's --write-segments) and the SAU2's asm reference bytes
# (tools/asm_compare.py --extract).  Without it only our image is checked.
#
# The SAU5 (make TARGET_SAU=sau5 check-rfc) has the SAU2's layout (load
# address, kernel offset and VA, split) and its own COLD (cold/sau5/
# cold_start.s): the operands after the first five, the MMU map table and
# its two computed cells are at other addresses, the table has more
# entries (the SAU5's I/O pages), and the 68020 fixups' I/O window starts
# at its IODEFS 0xF90000.  Its oracle json is tools/rfc_segments_sau5.json
# (rfc_decode.py --sau 5), and with no Ghidra extract of its image the
# oracle's loader is checked against the map instead (--map: every file
# segment of the kernel read through COLD's map equals the file's bytes at
# the map's `loaded at').
#
# The SAU8 (make TARGET_SAU=sau8 check-rfc) has the same kind of image
# (the SAU2's split and a fixup table at RELOC) at its own addresses: load
# 0x101C00, COLD 0xC00 bytes, the DUMP page 0x800 bytes at file 0xC00
# (VA 0x3C00400, copied to PPN 0x403), the kernel from file 0x1400 (VA
# 0x3C00C00), and its COLD (cold/sau8/cold_start.s) builds the MC68851's
# tables from a map table of the SAU2's form; its fixups move a cell by
# windows of the PMMU's layout from PROT up, and it has no MMU_$PTTX.
# The SAU-dependent scalars are set from the SAU tables by select_sau().
#
# The SAU3 (make TARGET_SAU=sau3 check-rfc) is laid out the same way, with
# its own COLD (cold/sau3/cold_start.s: three additions and a 19-entry map
# table, so everything after 0x101590 is further on), the SAU2's 68020
# fixup windows and VM tables, and its oracle json
# tools/rfc_segments_sau3.json (rfc_decode.py --sau 3), checked against
# the map as the SAU5's is.
#
# The items below are written for the SAU2, with its addresses.
#
# Our image (every item fails the check):
#   1. header: load 0x101400, start 0x101424 (= cold_start_entry), machine
#      WORD 2 (the SAU's number), then a zero word;
#   2. info block: 0xC00, OS_DATA, OS_PROC = 0xE00800, magic 0xFEED2B03
#      (word FEED, byte 2B, version bits 7..5 = 0), split 0x55F, MOVE_TO_PPN
#      0x600;
#   3. COLD (file 0..0x800) and DUMP (0x800..0xC00) byte-identical to the
#      original's, apart from the 32-bit cells both fixup tables list, and
#      the set of those cells identical (the image lists 47: 41 in COLD, 6
#      in DUMP);
#   4. .cold at VMA = LMA = 0x101400; every other loaded section at
#      VMA - LMA = 0xCFE800; the first kernel page at file 0xC00, page
#      aligned; every loaded section's file bytes equal the ELF's; the holes
#      between them are zeros; the file ends with the fixup table at RELOC;
#   5. the fixup table: count >= 1, entries even and inside the loaded
#      bytes, and the entries are exactly the ELF's R_68K_32 cells (computed
#      here independently of tools/gen_rfc_fixups.py); it ends within the
#      room .bss leaves it (RFC_FIXUP_TABLE_END) and no .bss object lies
#      under it;
#   6. COLD's operands (read from its bytes, as rfc_decode.py does) equal
#      the link's symbols; MMAP, MMU_$PTTX and P1_STACK_BASE lie in
#      [OS_PROC + 0x55C00, OS_PAGE_END); RELOC's low address is past
#      0x157C00;
#   7. the dry-run loader (below) maps every byte of DUMP, the kernel's
#      loaded sections and COLD to a physical page holding the ELF's byte,
#      maps every page OS_PROC..OS_PAGE_END exactly once, maps CRASH_$RECORD
#      to PPN 0x400, and finds the fixup table where COLD's 68020 path looks;
#   8. the VM tables' run-time windows:
#      AREA_$RPMAP_CACHE, MST, PIT_PAGES, MSTE_PAGES .. VM_TABLES_END =
#      IODEFS_GUARD lie in map order, page aligned, from OS_PAGE_END up;
#      no page of them is mapped by COLD (the dry-run loader's map) and no
#      allocated section other than `.vm_tables' overlaps them; MSTE_PAGES +
#      MST_MSTE_PAGES_MAX (0x166) pages <= VM_TABLES_END < 0xFA0000 (the
#      68020 fixups' I/O window) and <= DISP1_MEM 0xFC0000 (IODEFS, the
#      I/O space).  The same window check runs on the original with the
#      map's values (0xEE4C00 .. 0xF4FC00 past its OS_PAGE_END 0xEC4800).
#
# The loader model: sysboot puts file page i (1 KB) at PPN (0x101400 >> 10)
# + i, or, when that is >= the split PPN (info +16), at that - split +
# MOVE_TO_PPN (info +20) (sysboot 0x13E238); COLD copies DUMP to PPN 0x403,
# computes the kernel page count from OS_PAGE_END and fills the two map
# table cells (0x1015A6..0x1015CC), and cold_map_pages maps each entry of
# the 17-entry table at 0x101850 page by page (va += 0x400, ppn += 1).
#
# The original image (--orig) goes through the same loader: the run must
# reproduce tools/rfc_segments.json (the info block, COLD's constants, the
# map table with its two computed cells, the fixup table's size and window
# counts), and every run of tools/asm_image_ref.txt at a kernel VA must be
# found at the physical page the map gives that VA.

import argparse
import json
import os
import re
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rfc_elf  # noqa: E402

# The SAU whose image this checks (--sau; 2 by default).  The tables below
# that differ by SAU are keyed by it: NAME[2] the SAU2's COLD
# (cold/sau2/cold_start.s), NAME[3] the SAU3's (cold/sau3/cold_start.s),
# NAME[5] the SAU5's (cold/sau5/cold_start.s,
# the instruction addresses in its comments, checked against the SAU5
# image's bytes).  The scalar ones are the same in both.
SAU = 2
SAUS = (2, 3, 5, 8, 9)

# The RFC header's machine word: the SAU's number.
MACHINE = {2: 2, 3: 3, 5: 5, 8: 8}

# The image's layout, by SAU: the load address (file byte 0), COLD's
# size, the DUMP page's size and VA, the kernel's file offset and VA,
# OS_BEGIN, and the kernel bytes in the low piece (COLD's KERNEL_LO_BYTES).
LOADS = {2: 0x101400, 3: 0x101400, 5: 0x101400, 8: 0x101C00}
COLD_SIZES = {2: 0x800, 3: 0x800, 5: 0x800, 8: 0xC00}
DUMP_SIZES = {2: 0x400, 3: 0x400, 5: 0x400, 8: 0x800}
DUMP_VAS = {2: 0xE00400, 3: 0xE00400, 5: 0xE00400, 8: 0x3C00400}
KERNEL_VAS = {2: 0xE00800, 3: 0xE00800, 5: 0xE00800, 8: 0x3C00C00}
OS_BEGINS = {2: 0xE00000, 3: 0xE00000, 5: 0xE00000, 8: 0x3C00000}
LO_BYTES = {2: 0x55C00, 3: 0x55C00, 5: 0x55C00, 8: 0x54C00}

LOAD = 0x101400
PAGE = 0x400
INFO = 0x10140C
MOVE_TO_PPN = 0x101420
# COLD's MMU map table and its two cells COLD fills in (the kernel's low
# piece count; the high piece's count and PPN)
MAP_TABLE = {2: 0x101850, 3: 0x101890, 5: 0x1018DC,
             8: 0x102206}                       # cold_map_table
MAP_LO_COUNT = {2: 0x1018E6, 3: 0x10193A,
                5: 0x1019C2, 8: 0x102238}       # cold_map_kernel_lo_count
MAP_HI_COUNT_PPN = {2: 0x1018F0, 3: 0x101944,
                    5: 0x1019CC, 8: 0x102242}   # cold_map_kernel_hi_count_ppn
DUMP_LOW = 0x101C00
DUMP_PPN = 0x403
KERNEL_FILE = 0xC00
COLD_SIZE = 0x800
DUMP_SIZE = 0x400
DUMP_VA = 0xE00400
KERNEL_VA = 0xE00800
OS_BEGIN = 0xE00000
KERNEL_LO_BYTES = 0x55C00

# COLD operands (instruction + 2), the same in 10.2, 10.3 and ours; the
# first five are at the same addresses in the SAU5's COLD, the others
# moved (the SAU5's instruction addresses: move.l #OS_PAGE_END 0x1015C4,
# sub.l #OS_PROC 0x1015D4, cmp.l #0x55C00 0x1015DA, add.l #MMAP 0x101618,
# movea.l #P1_STACK_BASE 0x10176E, movea.l #OS_$INIT 0x10177C, adda.l
# #MMU_$PTTX 0x1017F4; the SAU3's 0x10159E, 0x1015AE, 0x1015B4, 0x1015F2,
# 0x101728, 0x101736, 0x1017A8)
# The SAU8's (cold/sau8/cold_start.s): movea.l #RELOC 0x101C98, suba.l
# #OS_PROC 0x101C9E, adda.l #0x103000 0x101CA4, cmpa.l #0x157C00 0x101CAA,
# move.l #OS_PAGE_END 0x101DFC, sub.l #OS_PROC 0x101E0C, cmp.l #0x54C00
# 0x101E12, add.l #MMAP 0x101E50, movea.l #P1_STACK_BASE 0x101F60,
# movea.l #OS_$INIT 0x101F6E; no OS_BEGIN window and no MMU_$PTTX (None).
OP_RELOC_VA_S = {2: 0x101496, 3: 0x101496, 5: 0x101496, 8: 0x101C9A}
OP_KERNEL_VA_S = {2: 0x10149C, 3: 0x10149C, 5: 0x10149C, 8: 0x101CA0}
OP_KERNEL_LOW_S = {2: 0x1014A2, 3: 0x1014A2, 5: 0x1014A2, 8: 0x101CA6}
OP_SPLIT_LOW_S = {2: 0x1014A8, 3: 0x1014A8, 5: 0x1014A8, 8: 0x101CAC}
OP_OS_BEGIN_S = {2: 0x1014E8, 3: 0x1014E8, 5: 0x1014E8, 8: None}
OP_RELOC_VA = 0x101496
OP_KERNEL_VA = 0x10149C
OP_KERNEL_LOW = 0x1014A2
OP_SPLIT_LOW = 0x1014A8
OP_OS_BEGIN = 0x1014E8
OP_PAGE_END = {2: 0x101592, 3: 0x1015A0, 5: 0x1015C6, 8: 0x101DFE}
OP_KERNEL_VA2 = {2: 0x1015A2, 3: 0x1015B0, 5: 0x1015D6, 8: 0x101E0E}
OP_LO_BYTES = {2: 0x1015A8, 3: 0x1015B6, 5: 0x1015DC, 8: 0x101E14}
OP_MMAP_VA = {2: 0x1015E6, 3: 0x1015F4, 5: 0x10161A, 8: 0x101E52}
OP_STACK = {2: 0x1016FA, 3: 0x10172A, 5: 0x101770, 8: 0x101F62}
OP_ENTRY = {2: 0x101708, 3: 0x101738, 5: 0x10177E, 8: 0x101F70}
OP_PTTX_VA = {2: 0x10176A, 3: 0x1017AA, 5: 0x1017F6, 8: None}


def select_sau(sau):
    """Set the SAU-dependent scalars from the tables."""
    global SAU, LOAD, INFO, MOVE_TO_PPN, DUMP_LOW, KERNEL_FILE, COLD_SIZE
    global DUMP_SIZE, DUMP_VA, KERNEL_VA, OS_BEGIN, KERNEL_LO_BYTES
    global OP_RELOC_VA, OP_KERNEL_VA, OP_KERNEL_LOW, OP_SPLIT_LOW, OP_OS_BEGIN
    SAU = sau
    if sau not in LOADS:
        return
    LOAD = LOADS[sau]
    INFO = LOAD + 0xC
    MOVE_TO_PPN = LOAD + 0x20
    COLD_SIZE = COLD_SIZES[sau]
    DUMP_SIZE = DUMP_SIZES[sau]
    DUMP_LOW = LOAD + COLD_SIZE
    KERNEL_FILE = COLD_SIZE + DUMP_SIZE
    DUMP_VA = DUMP_VAS[sau]
    KERNEL_VA = KERNEL_VAS[sau]
    OS_BEGIN = OS_BEGINS[sau]
    KERNEL_LO_BYTES = LO_BYTES[sau]
    OP_RELOC_VA = OP_RELOC_VA_S[sau]
    OP_KERNEL_VA = OP_KERNEL_VA_S[sau]
    OP_KERNEL_LOW = OP_KERNEL_LOW_S[sau]
    OP_SPLIT_LOW = OP_SPLIT_LOW_S[sau]
    OP_OS_BEGIN = OP_OS_BEGIN_S[sau]

# The VM tables' run-time windows: map names and the
# image's addresses (domain_os.10.2.map, VM_TABLES `D98 ED5000 size 7AC00';
# the SAU5 map's `D98 ECD400 VM_TABLES size = 7AC00'; the SAU3 map's `D99
# ED5000 VM_TABLES size = 7AC00', the SAU2's addresses).
VM_WINDOWS = {
    2: [('AREA_$RPMAP_CACHE', 0xEE4C00), ('MST', 0xEE5800),
        ('PIT_PAGES', 0xEE6400), ('MSTE_PAGES', 0xEF6400),
        ('VM_TABLES_END', 0xF4FC00)],
    3: [('AREA_$RPMAP_CACHE', 0xEE4C00), ('MST', 0xEE5800),
        ('PIT_PAGES', 0xEE6400), ('MSTE_PAGES', 0xEF6400),
        ('VM_TABLES_END', 0xF4FC00)],
    5: [('AREA_$RPMAP_CACHE', 0xEDD000), ('MST', 0xEDDC00),
        ('PIT_PAGES', 0xEDE800), ('MSTE_PAGES', 0xEEE800),
        ('VM_TABLES_END', 0xF48000)],
    # the SAU8's from OS_PAGE_END (SMAPS + 0x3400, inside `D52 3CCC800
    # OS_PMAPS'), as the SAU9's
    8: [('OS_PAGE_END', 0x3CF6400), ('SMAPS_END', 0x3DAF800),
        ('RARS_END', 0x3DB6C00), ('AST_PMAPS', 0x3DB7800),
        ('AREA_$RPMAP_CACHE', 0x3DE7800), ('MST', 0x3E4DC00),
        ('PIT_PAGES', 0x3E51400), ('MSTE_PAGES', 0x3E61400),
        ('VM_TABLES_END', 0x3F2E000)],
}
# VAs COLD's map table maps to two physical pages, in the original: the
# SAU5's DISP1 (0xFF9800, PPN 0x3C, then `the same VA, the next PPN' 0x3D,
# cold/sau5/cold_start.s 0x101954 and 0x10195E).  The loader allows them
# (the first PPN is the one it reads through).
DOUBLE_MAPPED = {2: set(), 3: set(), 5: {0xFF9800}, 8: {0x3C00400}}
# The SAU8's: the first entry maps OS_BEGIN's two pages (PPN 0x400, 0x401)
# and the next one DUMP's (PPN 0x403, 0x404) from OS_BEGIN + 0x400, so
# 0x3C00400 is in both (cold/sau8/cold_start.s cold_map_table); COLD writes
# the page descriptors in table order, so the last one is the page's, and
# with the MC68851 the fixups move the first entry away.
DOUBLE_MAPPED_LAST = {8}
# Map symbols in the VM-table windows whose page COLD maps itself: the
# SAU8's RARS, the root tables at physical 0x101400 (the map table's `1,
# 0x405, MAP_WIRED + RARS').
COLD_MAPPED_IN_WINDOWS = {8: ['RARS']}

MST_MSTE_PAGES_MAX = 0x166      # mst/mst.h, MST_$INIT 0x00E30CF8
# cold_start.s IO_WINDOW: from here the 68020 fixups treat a cell as I/O
IO_FIXUP_WINDOW = {2: 0xFA0000, 3: 0xFA0000, 5: 0xF90000,
                   8: 0x3F80000}   # the SAU8's last window
# IODEFS, arch/m68k/<sau>/iodefs.s: DISP1_MEM on the SAU2, KOLOR_CTL on the
# SAU5, the start of the I/O space on the SAU3
IODEFS = {2: 0xFC0000, 3: 0xFC0000, 5: 0xF90000, 8: 0x3FA0000}

# The 68020 fixups' windows on the value (COLD 0x1014C4..; the SAU5's from
# its IO_WINDOW and *_WINDOW_020 constants)
WINDOWS = {
    2: [(0xE00000, 0xFA0000, 'E00000..FA0000 +2F00000'),
        (0xFA0000, 0x4000000, 'FA0000..4000000 +3000000'),
        (0xCC0000, 0xE00000, 'CC0000..E00000 +2E00000'),
        (0x700000, 0x800000, '700000..800000 -300000')],
    3: [(0xE00000, 0xFA0000, 'E00000..FA0000 +2F00000'),
        (0xFA0000, 0x4000000, 'FA0000..4000000 +3000000'),
        (0xCC0000, 0xE00000, 'CC0000..E00000 +2E00000'),
        (0x700000, 0x800000, '700000..800000 -300000')],
    5: [(0xE00000, 0xF90000, 'E00000..F90000 +2F00000'),
        (0xF90000, 0x4000000, 'F90000..4000000 +3000000'),
        (0xCC0000, 0xE00000, 'CC0000..E00000 +2E00000'),
        (0x700000, 0x800000, '700000..800000 -300000')],
    # the SAU8's (COLD 0x101CCA..0x101D48, with the MC68851 only): PROT,
    # OS_PMAP0, SMAPS_END, RARS_END, MST and 0x3F80000 as the map's
    8: [(0x39C0000, 0x3CF2800, '39C0000..3CF2800 +B600000'),
        (0x3CF2800, 0x3DAF800, '3CF2800..3DAF800 +B60A000'),
        (0x3DAF800, 0x3DB6C00, '3DAF800..3DB6C00 +B896800'),
        (0x3DB6C00, 0x3E4DC00, '3DB6C00..3E4DC00 +B89C000'),
        (0x3E4DC00, 0x3F80000, '3E4DC00..3F80000 +B9D5800'),
        (0x3F80000, 0x4000000, '3F80000..4000000 +C000000')],
}


class Report:
    def __init__(self, title):
        self.title = title
        self.errors = []
        self.notes = []

    def check(self, ok, msg):
        if not ok:
            self.errors.append(msg)
        return ok

    def note(self, msg):
        self.notes.append(msg)

    def show(self):
        print('check_rfc: %s' % self.title)
        for n in self.notes:
            print('    ' + n)
        for e in self.errors[:40]:
            print('    FAIL: ' + e)
        if len(self.errors) > 40:
            print('    ... and %d more' % (len(self.errors) - 40))
        print('    %s' % ('ok' if not self.errors else
                         '%d problem(s)' % len(self.errors)))


class Image:
    def __init__(self, path):
        with open(path, 'rb') as f:
            self.d = f.read()
        self.end = LOAD + len(self.d)

    def b32(self, low):
        return struct.unpack_from('>I', self.d, low - LOAD)[0]

    def b16(self, low):
        return struct.unpack_from('>H', self.d, low - LOAD)[0]

    def bytes(self, low, n):
        return self.d[low - LOAD:low - LOAD + n]


def header_info(img, r):
    hdr = dict(load=img.b32(LOAD), start=img.b32(LOAD + 4),
               machine=img.b16(LOAD + 8), word10=img.b16(LOAD + 10))
    info = dict(kernel_offset=img.b32(INFO), data_va=img.b32(INFO + 4),
                kernel_va=img.b32(INFO + 8), magic=img.b32(INFO + 12),
                split_ppn=img.b32(INFO + 16), move_to_ppn=img.b32(INFO + 20))
    r.check(hdr['load'] == LOAD, 'header load 0x%X' % hdr['load'])
    r.check(hdr['start'] == LOAD + 0x24, 'header start 0x%X' % hdr['start'])
    r.check(hdr['machine'] == MACHINE[SAU], 'header machine word %d'
            % hdr['machine'])
    r.check(hdr['word10'] == 0, 'header word +10 is 0x%X' % hdr['word10'])
    m = info['magic']
    r.check(m >> 16 == 0xFEED and (m >> 8) & 0xFF == 0x2B and not m & 0xE0,
            'info magic 0x%08X' % m)
    r.check(info['kernel_offset'] == KERNEL_FILE,
            'info +0 is 0x%X' % info['kernel_offset'])
    r.check(info['split_ppn'] == 0x55F, 'info split 0x%X' % info['split_ppn'])
    r.check(info['move_to_ppn'] == 0x600,
            'info MOVE_TO_PPN 0x%X' % info['move_to_ppn'])
    return hdr, info


def cold_constants(img):
    cc = dict(reloc_va=img.b32(OP_RELOC_VA), kernel_va=img.b32(OP_KERNEL_VA),
              kernel_low=img.b32(OP_KERNEL_LOW),
              split_low=img.b32(OP_SPLIT_LOW),
              os_page_end=img.b32(OP_PAGE_END[SAU]),
              kernel_va2=img.b32(OP_KERNEL_VA2[SAU]),
              lo_bytes=img.b32(OP_LO_BYTES[SAU]),
              mmap_va=img.b32(OP_MMAP_VA[SAU]),
              initial_sp=img.b32(OP_STACK[SAU]), entry=img.b32(OP_ENTRY[SAU]))
    # operands a SAU's COLD does not have (the SAU8's: None)
    if OP_OS_BEGIN is not None:
        cc['os_begin'] = img.b32(OP_OS_BEGIN)
    if OP_PTTX_VA[SAU] is not None:
        cc['pttx_va'] = img.b32(OP_PTTX_VA[SAU])
    return cc


def fixup_table(img, reloc_low, r, exact_end):
    """count and entries of the table at reloc_low."""
    if not r.check(LOAD <= reloc_low <= img.end - 2,
                   'RELOC low 0x%X outside the file' % reloc_low):
        return []
    n = img.b16(reloc_low)
    r.check(n >= 1, 'fixup count 0 (dbf would run 65,536 times)')
    end = reloc_low + 2 + 4 * n
    if not r.check(end <= img.end, 'fixup table runs past EOF'):
        return []
    tail = img.bytes(end, img.end - end)
    if exact_end:
        r.check(not tail, 'the file has %d bytes after the fixup table'
                % len(tail))
    else:
        r.check(not any(tail), 'non-zero bytes after the fixup table')
    cells = [img.b32(reloc_low + 2 + 4 * i) for i in range(n)]
    bad = [c for c in cells if c & 1 or not LOAD <= c <= reloc_low - 4]
    r.check(not bad, '%d fixup entries odd or outside the loaded bytes '
            '(first 0x%X)' % (len(bad), bad[0] if bad else 0))
    return cells


def window_counts(img, cells):
    counts = {}
    for c in cells:
        if c & 1 or not LOAD <= c <= img.end - 4:
            continue     # already reported by fixup_table
        v = img.b32(c) & 0x3FFFFFF
        k = 'none'
        for lo, hi, name in WINDOWS[SAU]:
            if lo <= v < hi:
                k = name
                break
        counts[k] = counts.get(k, 0) + 1
    return counts


class Loader:
    """sysboot's page placement, then COLD up to cold_map_pages."""

    def __init__(self, img, info, cc, r):
        self.img = img
        self.r = r
        split, move = info['split_ppn'], info['move_to_ppn']
        self.phys = {}
        for i in range(0, len(img.d), PAGE):
            ppn = (LOAD + i) >> 10
            if ppn >= split:
                ppn = ppn - split + move
            r.check(ppn not in self.phys, 'sysboot puts two file pages at '
                    'PPN 0x%X' % ppn)
            r.check(not 0x5F3 <= ppn < 0x600, 'file page 0x%X lands in '
                    'sysboot\'s own area (PPN 0x%X)' % (i, ppn))
            self.phys[ppn] = bytearray(img.d[i:i + PAGE].ljust(PAGE, b'\0'))
        # COLD 0x10154E: DUMP to PPN 0x403 (the SAU8's two pages, COLD
        # 0x101D5A, to PPN 0x403 and 0x404)
        for k in range(DUMP_SIZE // PAGE):
            self.phys[DUMP_PPN + k] = bytearray(
                img.bytes(DUMP_LOW + k * PAGE, PAGE))
        # COLD 0x101590..0x1015CC: the kernel page count
        kva, lo_bytes = cc['kernel_va2'], cc['lo_bytes']
        nbytes = ((cc['os_page_end'] + 0x3FF) & ~0x3FF) - kva
        self.kernel_pages = nbytes >> 10
        # the page of COLD that holds the two cells (0x101800..0x101C00;
        # the SAU8's 0x102000..0x102400)
        cpage = MAP_LO_COUNT[SAU] & ~0x3FF
        cold = self.phys[cpage >> 10]
        if nbytes <= lo_bytes:
            struct.pack_into('>H', cold, MAP_LO_COUNT[SAU] - cpage,
                             nbytes >> 10)
            self.lo_pages, self.hi_pages = nbytes >> 10, 0
        else:
            struct.pack_into('>I', cold, MAP_HI_COUNT_PPN[SAU] - cpage,
                             ((nbytes - lo_bytes) >> 10) << 16 | move)
            self.lo_pages = struct.unpack_from(
                '>H', cold, MAP_LO_COUNT[SAU] - cpage)[0]
            self.hi_pages = (nbytes - lo_bytes) >> 10
        # cold_map_pages: the table, page by page
        self.entries = []
        self.vmap = {}
        at = MAP_TABLE[SAU]
        while True:
            pg = self.phys[at >> 10]
            o = at & 0x3FF
            cnt, ppn = struct.unpack_from('>HH', pg, o)
            if cnt == 0:
                break
            va_f, prot = struct.unpack_from('>IH', pg, o + 4)
            va = va_f & 0x1FFFFFFF
            self.entries.append(dict(at=at, count=cnt, ppn=ppn, va=va,
                                     flags=va_f >> 29, prot=prot))
            for k in range(cnt):
                v = (va >> 10) + k
                if v in self.vmap and (v << 10) in DOUBLE_MAPPED[SAU]:
                    if SAU not in DOUBLE_MAPPED_LAST:
                        continue
                else:
                    r.check(v not in self.vmap, 'VA 0x%X mapped twice'
                            % (v << 10))
                self.vmap[v] = ppn + k
            at += 10
            if at >= LOAD + COLD_SIZE - 4:
                r.check(False, 'map table not terminated')
                break

    def read(self, va, n):
        """n bytes at VA through the map (None if a page is not mapped or
        not loaded)."""
        out = bytearray()
        while n:
            ppn = self.vmap.get(va >> 10)
            if ppn is None:
                return None
            pg = self.phys.get(ppn)
            o = va & 0x3FF
            k = min(n, PAGE - o)
            out += pg[o:o + k] if pg is not None else bytes(k)
            va += k
            n -= k
        return bytes(out)

    def mapped(self, va):
        return (va >> 10) in self.vmap

    def table_phys(self, cc, info):
        """COLD 0x101494..0x1014BE: where the 68020 path reads the table."""
        a0 = cc['reloc_va'] - cc['kernel_va'] + cc['kernel_low']
        if a0 <= cc['split_low']:
            return a0, None
        return a0, a0 - cc['split_low'] + (info['move_to_ppn'] << 10)


def check_vm_windows(r, ld, wins, os_page_end, iodefs, sections=(),
                     cold_mapped=()):
    """Item 8: the run-time windows `wins' [(name, va)] (the last is
    VM_TABLES_END) against COLD's map `ld' and the allocated `sections'
    [(name, lo, hi)] that must not overlap them."""
    vas = [va for _, va in wins]
    lo, hi = vas[0], vas[-1]
    r.check(all(v is not None for v in vas), 'a VM-table window symbol is '
            'missing: %s' % [n for n, v in wins if v is None])
    if any(v is None for v in vas):
        return
    r.check(all(a < b for a, b in zip(vas, vas[1:])),
            'the VM-table windows are not in map order: %s'
            % ', '.join('%s 0x%X' % w for w in wins))
    r.check(all(v % PAGE == 0 for v in vas),
            'a VM-table window does not start a page')
    r.check(lo >= os_page_end, 'the VM-table windows start at 0x%X, below '
            'OS_PAGE_END 0x%X' % (lo, os_page_end))
    mapped = [p << 10 for p in range(lo >> 10, hi >> 10) if p in ld.vmap
              and (p << 10) not in cold_mapped]
    r.check(not mapped, '%d page(s) of the VM-table windows 0x%X..0x%X are '
            'mapped by COLD (first 0x%X): the kernel installs fresh pages '
            'there' % (len(mapped), lo, hi, mapped[0] if mapped else 0))
    for name, a, b in sections:
        r.check(b <= lo or a >= hi, 'section %s 0x%X..0x%X overlaps the '
                'VM-table windows 0x%X..0x%X' % (name, a, b, lo, hi))
    mste = dict(wins)['MSTE_PAGES']
    r.check(mste + MST_MSTE_PAGES_MAX * PAGE <= hi,
            'MSTE_PAGES 0x%X + 0x%X pages is past VM_TABLES_END 0x%X'
            % (mste, MST_MSTE_PAGES_MAX, hi))
    r.check(hi < IO_FIXUP_WINDOW[SAU] and hi <= iodefs,
            'VM_TABLES_END 0x%X is not below the 68020 I/O fixup window '
            '0x%X and IODEFS 0x%X' % (hi, IO_FIXUP_WINDOW[SAU], iodefs))
    r.note('VM-table windows (run time, not mapped by COLD): %s; %d KB, '
           '0x%X below IODEFS' % (', '.join('%s 0x%X' % w for w in wins),
                                  (hi - lo) >> 10, iodefs - hi))


def elf_r68k_32_cells(elf):
    cells = set()
    for sec, vma, typ, _, _ in elf.relocations():
        if sec.loaded and typ == rfc_elf.R_68K_32:
            cells.add(vma - sec.addr + sec.lma)
    return cells


def check_ours(a, orig_cells_low):
    r = Report('our image %s' % a.image)
    img = Image(a.image)
    elf = rfc_elf.Elf(a.elf)
    sym = elf.symbol

    hdr, info = header_info(img, r)
    r.check(hdr['start'] == sym('cold_start_entry'),
            'start is not cold_start_entry')
    r.check(info['data_va'] == sym('OS_DATA'),
            'info +4 0x%X is not OS_DATA' % info['data_va'])
    r.check(info['kernel_va'] == sym('OS_PROC') == KERNEL_VA,
            'info +8 0x%X / OS_PROC' % info['kernel_va'])

    # 4. sections, LMAs, bytes
    loaded = sorted((s for s in elf.sections if s.loaded),
                    key=lambda s: s.lma)
    delta = KERNEL_VA - (LOAD + KERNEL_FILE)
    pos = LOAD
    for s in loaded:
        if s.name == '.cold':
            r.check(s.addr == s.lma == LOAD and s.size == COLD_SIZE,
                    '.cold at VMA 0x%X LMA 0x%X size 0x%X'
                    % (s.addr, s.lma, s.size))
        else:
            r.check(s.addr - s.lma == delta, '%s: VMA - LMA = 0x%X, not '
                    '0x%X' % (s.name, s.addr - s.lma, delta))
        mine, want = img.bytes(s.lma, s.size), elf.contents(s)
        if not r.check(mine == want, '%s: file bytes differ from the ELF'
                       % s.name):
            diff = next((i for i in range(min(len(mine), len(want)))
                         if mine[i] != want[i]), min(len(mine), len(want)))
            r.errors[-1] += ' (first at file 0x%X = low 0x%X, VMA 0x%X)' % (
                s.lma - LOAD + diff, s.lma + diff, s.addr + diff)
        r.check(not any(img.bytes(pos, s.lma - pos)),
                'non-zero hole before %s' % s.name)
        pos = s.lma + s.size
    dump, text = elf.section('.dump'), elf.section('.text')
    r.check(dump is not None and dump.lma == DUMP_LOW and
            dump.addr == DUMP_VA and dump.size == DUMP_SIZE,
            '.dump is not 0x%X bytes at file 0x%X / VMA 0x%X'
            % (DUMP_SIZE, COLD_SIZE, DUMP_VA))
    r.check(text is not None and text.lma == LOAD + KERNEL_FILE and
            text.addr == sym('OS_PROC') and not text.addr & 0x3FF,
            '.text does not start the kernel at file 0x%X on a page'
            % KERNEL_FILE)
    reloc = sym('RELOC')
    reloc_low = pos
    r.check(reloc - delta == reloc_low, 'RELOC 0x%X is not the end of the '
            'loaded bytes (low 0x%X)' % (reloc, reloc_low))
    r.check(reloc_low > 0x157C00, 'RELOC low 0x%X is not past 0x157C00'
            % reloc_low)

    # 5. the fixup table
    cells = fixup_table(img, reloc_low, r, exact_end=True)
    room = sym('RFC_FIXUP_TABLE_END')
    tend = reloc + 2 + 4 * len(cells)
    r.check(room is not None and tend <= room, 'the fixup table ends at '
            '0x%X, past the room kernel.ld leaves (RFC_FIXUP_TABLE_END %s)'
            % (tend, room))
    bss_objs = [v for n, v, sz, info, shndx in elf.symbols()
                if shndx == elf.section('.bss').index and sz and
                info & 0xF == 1]
    r.check(room is not None and bss_objs and min(bss_objs) >= room,
            'a .bss object lies under the fixup table')
    want = elf_r68k_32_cells(elf)
    r.check(set(cells) == want or (not want and cells == [LOAD]),
            'fixup entries differ from the ELF\'s R_68K_32 cells (%d vs %d)'
            % (len(cells), len(want)))

    # 3. COLD and DUMP against the original
    if orig_cells_low is not None:
        orig = Image(a.orig)
        mine_low = {c for c in cells if c < LOAD + KERNEL_FILE}
        r.check(mine_low == orig_cells_low,
                'COLD/DUMP relocation cells differ from the original\'s: '
                'missing %s, extra %s'
                % (sorted(hex(c) for c in orig_cells_low - mine_low)[:6],
                   sorted(hex(c) for c in mine_low - orig_cells_low)[:6]))
        masked = set()
        for c in mine_low:
            masked.update(range(c, c + 4))
        diff = [LOAD + i for i in range(KERNEL_FILE)
                if LOAD + i not in masked and
                img.d[i] != orig.d[i]]
        r.check(not diff, '%d byte(s) of COLD/DUMP differ outside '
                'relocation cells (first low 0x%X)'
                % (len(diff), diff[0] if diff else 0))
        nval = sum(1 for c in mine_low if img.b32(c) != orig.b32(c))
        r.note('COLD+DUMP (file 0..0xC00): identical to the original '
               'modulo %d relocation cells (%d hold different values: '
               'our link\'s addresses)' % (len(mine_low), nval))

    # 6. COLD's operands
    cc = cold_constants(img)
    expect = dict(reloc_va=reloc, kernel_va=sym('OS_PROC'),
                  kernel_va2=sym('OS_PROC'), os_begin=sym('OS_BEGIN'),
                  os_page_end=sym('OS_PAGE_END'),
                  mmap_va=sym('MMAP'), pttx_va=sym('MMU_$PTTX'),
                  initial_sp=sym('P1_STACK_BASE'),
                  entry=sym('OS_$INIT'), kernel_low=LOAD + KERNEL_FILE,
                  split_low=0x157C00, lo_bytes=KERNEL_LO_BYTES)
    for k, v in expect.items():
        if k not in cc:
            continue     # an operand this SAU's COLD does not have
        r.check(cc[k] == v, 'COLD operand %s = 0x%X, expected 0x%X'
                % (k, cc[k], v))
    hi = cc['kernel_va'] + cc['lo_bytes']
    for k in [k for k in ('mmap_va', 'pttx_va', 'initial_sp') if k in cc]:
        r.check(hi <= cc[k] < cc['os_page_end'], '%s 0x%X not in the high '
                'piece 0x%X..0x%X' % (k, cc[k], hi, cc['os_page_end']))
    bss = elf.section('.bss')
    r.check(cc['os_page_end'] == (bss.addr + bss.size + 0x3FF) & ~0x3FF,
            'OS_PAGE_END is not the end of .bss rounded to a page')

    # 7. the dry-run loader
    ld = Loader(img, info, cc, r)
    nbytes = 0
    for s in loaded:
        if s.name == '.cold':
            continue     # identity-mapped, and COLD rewrites two cells
        got = ld.read(s.addr, s.size)
        r.check(got == elf.contents(s), '%s: the bytes at its VAs through '
                'the MMU map differ from the ELF' % s.name)
        nbytes += s.size
    unmapped = [p << 10 for p in range(cc['kernel_va'] >> 10,
                                       cc['os_page_end'] >> 10)
                if p not in ld.vmap]
    r.check(not unmapped, '%d kernel page(s) not mapped (first 0x%X)'
            % (len(unmapped), unmapped[0] if unmapped else 0))
    crash = sym('CRASH_$RECORD')
    r.check(ld.vmap.get(crash >> 10) == 0x400 and
            ld.vmap.get(sym('LOG_$LAST_ENTRY') >> 10) == 0x400,
            'CRASH_$RECORD / LOG_$LAST_ENTRY not in the page COLD maps to '
            'PPN 0x400')
    ppns = [p for e in ld.entries if e['va'] >= OS_BEGIN or
            e['va'] == LOAD for p in range(e['ppn'], e['ppn'] + e['count'])]
    r.check(len(ppns) == len(set(ppns)), 'a physical page is mapped twice')
    a0, tphys = ld.table_phys(cc, info)
    r.check(tphys is not None and
            ld.phys.get(tphys >> 10, b'')[tphys & 0x3FF:(tphys & 0x3FF) + 2]
            == img.bytes(reloc_low, 2),
            'COLD\'s 68020 path does not find the fixup table')
    # 8. the VM tables' run-time windows
    wins = [(n, sym(n)) for n, _ in VM_WINDOWS[SAU]]
    r.check(sym('IODEFS_GUARD') == sym('VM_TABLES_END'),
            'IODEFS_GUARD is not VM_TABLES_END')
    vmt = elf.section('.vm_tables')
    r.check(vmt is not None and vmt.addr == sym(VM_WINDOWS[SAU][0][0]) and
            vmt.addr + vmt.size == sym('VM_TABLES_END') and not vmt.loaded,
            '.vm_tables is not the NOBITS %s..VM_TABLES_END'
            % VM_WINDOWS[SAU][0][0])
    others = [(x.name, x.addr, x.addr + x.size) for x in elf.sections
              if x.alloc and x.size and x.name != '.vm_tables']
    check_vm_windows(r, ld, wins, cc['os_page_end'], sym('IODEFS'),
                     others, [sym(n) for n in
                              COLD_MAPPED_IN_WINDOWS.get(SAU, [])])
    top = 0
    for e in ld.entries:
        if e['va'] >= OS_BEGIN:
            top = max(top, (e['ppn'] + e['count']) << 10)
    r.note('file %d bytes (0x%X): header+COLD 0x%X, DUMP 0x%X, kernel '
           '0x%X (VA 0x%X..0x%X, low 0x%X..0x%X), fixup table %d entries'
           % (len(img.d), len(img.d), COLD_SIZE, DUMP_SIZE,
              reloc_low - (LOAD + KERNEL_FILE),
              cc['kernel_va'], reloc, LOAD + KERNEL_FILE, reloc_low,
              len(cells)))
    r.note('info: 0x%X, OS_DATA 0x%X, OS_PROC 0x%X, 0x%08X, 0x%X, 0x%X'
           % (info['kernel_offset'], info['data_va'], info['kernel_va'],
              info['magic'], info['split_ppn'], info['move_to_ppn']))
    r.note('COLD: RELOC 0x%X (low 0x%X, phys 0x%X), OS_PAGE_END 0x%X: %d '
           'kernel pages = 0x%X low at PPN 0x%X + 0x%X high at PPN 0x%X; '
           'MMAP 0x%X, MMU_$PTTX 0x%X, P1_STACK_BASE 0x%X, OS_$INIT 0x%X; '
           'RAM needed through phys 0x%X'
           % (reloc, a0, tphys or 0, cc['os_page_end'], ld.kernel_pages,
              ld.lo_pages, (LOAD + KERNEL_FILE) >> 10, ld.hi_pages,
              info['move_to_ppn'], cc['mmap_va'], cc.get('pttx_va', 0),
              cc['initial_sp'], cc['entry'], top))
    wc = window_counts(img, cells)
    r.note('fixup windows: %s' % ', '.join('%s %d' % kv for kv in
                                            sorted(wc.items())))
    r.note('dry-run loader: %d MMU map entries; %d loaded bytes of %d '
           'sections (DUMP and the kernel) found at their VAs; %d kernel '
           'pages mapped' % (len(ld.entries), nbytes, len(loaded) - 1,
                             ld.kernel_pages))
    r.show()
    return not r.errors


def check_orig(a):
    """The oracle: the same loader over the original image."""
    r = Report('original image %s (oracle)' % a.orig)
    img = Image(a.orig)
    seg = json.load(open(a.segments))
    hdr, info = header_info(img, r)
    for k, v in seg['info'].items():
        r.check(info[k] == int(v, 16), 'info %s 0x%X, json %s'
                % (k, info[k], v))
    cc = cold_constants(img)
    for k, v in seg['cold_constants'].items():
        if k == 'move_to_phys':
            r.check(info['move_to_ppn'] << 10 == int(v, 16), k)
            continue
        r.check(cc[k] == int(v, 16), 'COLD %s 0x%X, json %s' % (k, cc[k], v))
    delta = cc['kernel_va'] - cc['kernel_low']
    reloc_low = cc['reloc_va'] - delta
    cells = fixup_table(img, reloc_low, r, exact_end=False)
    r.check(len(cells) == seg['reloc']['entries'], 'fixup count %d, json %d'
            % (len(cells), seg['reloc']['entries']))
    r.check(window_counts(img, cells) == seg['reloc']['window_counts'],
            'fixup window counts differ from the json')
    below = {c for c in cells if c < LOAD + KERNEL_FILE}
    r.check(below == {int(c, 16) for c in seg['reloc']['cells_below_kernel']},
            'cells below the kernel differ from the json')

    ld = Loader(img, info, cc, r)
    want = seg['mmu_map_table']
    got = [dict(at=hex(e['at']), count=e['count'], ppn=hex(e['ppn']),
                va=hex(e['va']), prot=hex(e['prot'])) for e in ld.entries]
    exp = [dict(at=e['at'], count=e['count'], ppn=e['ppn'], va=e['va'],
                prot=e['prot']) for e in want]
    r.check(got == exp, 'the MMU map table differs from the json')
    unmapped = [p for p in range(cc['kernel_va'] >> 10,
                                 cc['os_page_end'] >> 10)
                if p not in ld.vmap]
    r.check(not unmapped, '%d kernel pages not mapped' % len(unmapped))
    check_vm_windows(r, ld, VM_WINDOWS[SAU], cc['os_page_end'], IODEFS[SAU],
                     cold_mapped=[map_symbol(a.map, n) for n in
                                  COLD_MAPPED_IN_WINDOWS.get(SAU, [])]
                     if a.map else ())
    nruns = nok = 0
    for line in (open(a.ref) if a.ref else []):
        if line.startswith('#') or not line.strip():
            continue
        va_s, _, hx = line.split()
        va = int(va_s, 16)
        if va < OS_BEGIN:
            continue     # COLD's own runs: file bytes, checked by item 3
        nruns += 1
        b = bytes.fromhex(hx)
        if r.check(ld.read(va, len(b)) == b, 'asm-ref run at VA 0x%X not '
                   'at its mapped physical page' % va):
            nok += 1
    a0, tphys = ld.table_phys(cc, info)
    r.check(tphys is not None and
            ld.phys[tphys >> 10][tphys & 0x3FF:(tphys & 0x3FF) + 2] ==
            img.bytes(reloc_low, 2), 'COLD does not find the fixup table')
    r.note('info: 0x%X, .DATA 0x%X, 0x%X, 0x%08X, 0x%X, 0x%X'
           % (info['kernel_offset'], info['data_va'], info['kernel_va'],
              info['magic'], info['split_ppn'], info['move_to_ppn']))
    r.note('COLD: RELOC 0x%X (low 0x%X, phys 0x%X), OS_PAGE_END 0x%X: %d '
           'kernel pages = 0x%X low + 0x%X high at PPN 0x%X; fixup table '
           '%d entries (%d below the kernel)'
           % (cc['reloc_va'], a0, tphys or 0, cc['os_page_end'],
              ld.kernel_pages, ld.lo_pages, ld.hi_pages,
              info['move_to_ppn'], len(cells), len(below)))
    if a.ref:
        r.note('dry-run loader: %d MMU map entries (json agrees); %d/%d '
               'asm-ref runs at kernel VAs found at their mapped physical '
               'pages' % (len(ld.entries), nok, nruns))
    if a.map:
        # every file segment of DUMP and the kernel (the map's `loaded at'
        # is its low address) read through COLD's map is the file's bytes
        nseg = nbytes = 0
        for kind, va, size, low in map_file_segments(a.map):
            if not OS_BEGIN <= va < cc['reloc_va'] or not size or \
                    not LOAD <= low <= img.end - size:
                continue    # not in the file (CRASH_RECORD, the bss)
            nseg += 1
            nbytes += size
            r.check(ld.read(va, size) == img.bytes(low, size),
                    'map segment at VA 0x%X (loaded at 0x%X, 0x%X bytes) '
                    'is not at its mapped physical pages' % (va, low, size))
        r.note('dry-run loader: %d MMU map entries (json agrees); %d map '
               'segments of DUMP and the kernel (%d bytes) found at their '
               'mapped physical pages' % (len(ld.entries), nseg, nbytes))
    r.show()
    return not r.errors, below


def map_file_segments(path):
    """(kind, VA, size, loaded at) of the map's numbered load regions."""
    # fixed columns: kind, a 2-column section number, an 8-column address
    # (an 8-digit address runs into the number: the SAU9's `D993C000000')
    pat = re.compile(r'^([ID])([ \d]{2})([ 0-9A-F]{8})\s+\S+\s+loaded at\s+'
                     r'([0-9A-F]+), size = ([0-9A-F]+)')
    out = []
    for line in open(path, encoding='latin-1'):
        m = pat.match(line)
        if m and m.group(2).strip():
            out.append((m.group(1), int(m.group(3), 16), int(m.group(5), 16),
                        int(m.group(4), 16)))
    return out



# ---------------------------------------------------------------------------
# The SAU9: a 12-byte info block (kernel offset
# 0x2000, .DATA's VA, the first kernel page's VA), no split and no fixup
# table; COLD (cold/sau9/cold_start.s) copies the DUMP page (file 0x1800)
# to physical 0x4001400, and OS_$COLD_START (os/cold.pas) maps the pages of
# its boot map table, the OS_COLD module's data (the map's `D 4002FFC
# OS_COLD size = 6C'): 9 entries of (physical address, VA, page count,
# flags), the kernel's count 0 (its pages OS_PROC .. OS_PAGE_END).  The
# loader below: the file at LOAD, contiguous; DUMP copied; each entry's
# pages mapped.
# ---------------------------------------------------------------------------

LOAD9 = 0x04002400
COLD9_SIZE = 0x1800         # COLD, then DUMP at file 0x1800
DUMP9_PHYS = 0x04001400
DUMP9_SIZE = 0x800
KERNEL9_FILE = 0x2000
BOOT_MAP_ENTRIES = 9


class Image9:
    def __init__(self, path):
        with open(path, 'rb') as f:
            self.d = f.read()
        self.end = LOAD9 + len(self.d)

    def b32(self, low):
        return struct.unpack_from('>I', self.d, low - LOAD9)[0]

    def b16(self, low):
        return struct.unpack_from('>H', self.d, low - LOAD9)[0]

    def bytes(self, low, n):
        return self.d[low - LOAD9:low - LOAD9 + n]


def header9(img):
    return dict(load=img.b32(LOAD9), start=img.b32(LOAD9 + 4),
                machine=img.b16(LOAD9 + 8), word10=img.b16(LOAD9 + 10),
                kernel_offset=img.b32(LOAD9 + 12), data_va=img.b32(LOAD9 + 16),
                kernel_va=img.b32(LOAD9 + 20))


def boot_map(img, at):
    out = []
    for i in range(BOOT_MAP_ENTRIES):
        e = at + 12 * i
        out.append(dict(at=e, phys=img.b32(e), va=img.b32(e + 4),
                        count=img.b16(e + 8), flags=img.b16(e + 10)))
    return out


class Loader9:
    """Physical memory as sysboot and COLD leave it, and the boot map's
    VA -> physical pages."""

    def __init__(self, img, entries, os_page_end, r):
        self.img = img
        self.vmap = {}
        self.kernel_pages = 0
        for e in entries:
            n = e['count']
            if n == 0:
                # the kernel's entry: OS_PROC .. OS_PAGE_END
                n = (os_page_end - e['va'] + 0x3FF) >> 10
                self.kernel_pages = n
            for k in range(n):
                v = (e['va'] >> 10) + k
                r.check(v not in self.vmap, 'VA 0x%X mapped twice' % (v << 10))
                self.vmap[v] = (e['phys'] >> 10) + k

    def phys_byte_page(self, ppn):
        """The bytes of physical page ppn (DUMP's copy, else the file)."""
        pa = ppn << 10
        if DUMP9_PHYS <= pa < DUMP9_PHYS + DUMP9_SIZE:
            return self.img.bytes(LOAD9 + COLD9_SIZE + pa - DUMP9_PHYS, PAGE)
        if LOAD9 <= pa < self.img.end:
            return self.img.bytes(pa, PAGE)
        return None

    def read(self, va, n):
        out = b''
        while n > 0:
            ppn = self.vmap.get(va >> 10)
            if ppn is None:
                return None
            page = self.phys_byte_page(ppn)
            if page is None:
                return None
            o = va & 0x3FF
            k = min(n, PAGE - o)
            out += page[o:o + k]
            va += k
            n -= k
        return out


def map_symbol(path, name):
    pat = re.compile(r'^ +([0-9A-F]+)  (\S+)\s*$')
    for line in open(path, encoding='latin-1'):
        m = pat.match(line)
        if m and m.group(2) == name:
            return int(m.group(1), 16)
    return None


def map_segment(path, name):
    pat = re.compile(r'^D +([0-9A-F]+)  (\S+)\s+size = ([0-9A-F]+)')
    for line in open(path, encoding='latin-1'):
        m = pat.match(line)
        if m and m.group(2) == name:
            return int(m.group(1), 16), int(m.group(3), 16)
    return None


def check_orig9(a):
    r = Report('original image %s (oracle)' % a.orig)
    img = Image9(a.orig)
    seg = json.load(open(a.segments)) if a.segments else None
    hdr = header9(img)
    r.check(hdr['load'] == LOAD9 and hdr['machine'] == 9 and
            hdr['kernel_offset'] == KERNEL9_FILE,
            'header/info: load 0x%X machine %d kernel offset 0x%X'
            % (hdr['load'], hdr['machine'], hdr['kernel_offset']))
    at, size = map_segment(a.map, 'OS_COLD')
    r.check(size == 12 * BOOT_MAP_ENTRIES, 'OS_COLD data is 0x%X bytes' % size)
    entries = boot_map(img, at)
    os_page_end = map_symbol(a.map, 'OS_PAGE_END')
    if seg:
        for k, v in seg['header'].items():
            r.check(hdr[k] == int(v, 16), 'header %s 0x%X, json %s'
                    % (k, hdr[k], v))
        got = [dict(at=hex(e['at']), phys=hex(e['phys']), va=hex(e['va']),
                    count=e['count'], flags=hex(e['flags'])) for e in entries]
        r.check(got == seg['boot_map'], 'the boot map table differs from '
                'the json')
    ld = Loader9(img, entries, os_page_end, r)
    unmapped = [p for p in range(hdr['kernel_va'] >> 10, os_page_end >> 10)
                if p not in ld.vmap]
    r.check(not unmapped, '%d kernel pages not mapped' % len(unmapped))
    nseg = nbytes = 0
    for kind, va, size, low in map_file_segments(a.map):
        if not size or va < 0x3C400000 or not LOAD9 <= low <= img.end - size \
                or low < LOAD9 + COLD9_SIZE:
            continue    # COLD's own, or not in the file
        nseg += 1
        nbytes += size
        r.check(ld.read(va, size) == img.bytes(low, size),
                'map segment at VA 0x%X (loaded at 0x%X, 0x%X bytes) is not '
                'at its mapped physical pages' % (va, low, size))
    r.note('header: load 0x%X, start 0x%X, machine %d; info: 0x%X, .DATA '
           '0x%X, 0x%X; no fixup table; file 0x%X bytes'
           % (hdr['load'], hdr['start'], hdr['machine'], hdr['kernel_offset'],
              hdr['data_va'], hdr['kernel_va'], len(img.d)))
    r.note('dry-run loader: %d boot map entries%s, the kernel %d pages to '
           'OS_PAGE_END 0x%X; %d map segments of DUMP and the kernel (%d '
           'bytes) found at their mapped physical pages'
           % (len(entries), ' (json agrees)' if seg else '', ld.kernel_pages,
              os_page_end, nseg, nbytes))
    r.show()
    return not r.errors


def check_ours9(a):
    r = Report('%s (ours, %s)' % (a.image, a.elf))
    img = Image9(a.image)
    elf = rfc_elf.Elf(a.elf)
    sym = elf.symbol
    hdr = header9(img)
    r.check(hdr['load'] == LOAD9 == sym('RFC_LOAD'), 'load 0x%X' % hdr['load'])
    r.check(hdr['start'] == sym('cold_start_entry'), 'start is not '
            'cold_start_entry')
    r.check(hdr['machine'] == 9 and hdr['word10'] == 0, 'machine word')
    r.check(hdr['kernel_offset'] == KERNEL9_FILE, 'kernel offset 0x%X'
            % hdr['kernel_offset'])
    r.check(hdr['data_va'] == sym('OS_DATA'), 'info .DATA is not OS_DATA')
    r.check(hdr['kernel_va'] == sym('OS_PROC'), 'info kernel VA is not '
            'OS_PROC')
    reloc = sym('RELOC')
    loaded = [s for s in elf.sections if s.loaded]
    last = max(loaded, key=lambda s: s.lma + s.size)
    reloc_low = last.lma + last.size
    r.check(img.end == reloc_low, 'the file ends at 0x%X, RELOC\'s low '
            'address is 0x%X (no fixup table)' % (img.end, reloc_low))
    r.check(sym('RFC_FIXUP_TABLE_END') == reloc, 'room for a fixup table')
    # every loaded section's bytes in the file at its LMA
    for s in loaded:
        r.check(img.bytes(s.lma, s.size) == elf.contents(s),
                '%s is not at its LMA in the file' % s.name)
    # COLD_START and DUMP against the original, but for our relocation
    # cells (the kernel's addresses differ by our layout)
    if a.orig:
        orig = Image9(a.orig)
        cells = set()
        for sec, vma, typ, name, addend in elf.relocations():
            if sec.loaded and typ == rfc_elf.R_68K_32:
                cells.update(range(vma - sec.addr + sec.lma,
                                   vma - sec.addr + sec.lma + 4))
            elif sec.loaded and typ in (rfc_elf.R_68K_16, rfc_elf.R_68K_PC16):
                cells.update(range(vma - sec.addr + sec.lma,
                                   vma - sec.addr + sec.lma + 2))
        cold_start = map_segment(a.map, 'COLD_START')[1]
        for lo, n, what in ((LOAD9, cold_start, 'COLD_START'),
                            (LOAD9 + COLD9_SIZE, DUMP9_SIZE, 'DUMP')):
            diff = [x for x in range(lo, lo + n) if x not in cells and
                    img.bytes(x, 1) != orig.bytes(x, 1)]
            r.check(not diff, '%s differs from the original outside our '
                    'relocation cells at %d byte(s), first 0x%X'
                    % (what, len(diff), diff[0] if diff else 0))
    # the boot map table as OS_$COLD_START reads it: OS_COLD's data block,
    # which starts at cold_start.s's cold_stack_top (`D 4002FFC OS_COLD')
    at = sym('cold_stack_top') or \
        (sym('RFC_LOAD') + map_segment(a.map, 'OS_COLD')[0] - LOAD9
         if a.map else None)
    entries = boot_map(img, at)
    ld = Loader9(img, entries, sym('OS_PAGE_END'), r)
    for s in loaded:
        if s.addr < 0x3C400000:
            continue        # COLD, identity mapped
        got = ld.read(s.addr, s.size)
        r.check(got == img.bytes(s.lma, s.size), '%s (VA 0x%X..0x%X) is not '
                'at its mapped physical pages' % (s.name, s.addr,
                                                 s.addr + s.size))
    unmapped = [p for p in range(sym('OS_PROC') >> 10, sym('OS_PAGE_END') >> 10)
                if p not in ld.vmap]
    r.check(not unmapped, '%d kernel pages below OS_PAGE_END not mapped'
            % len(unmapped))
    # the run-time windows get pages at run time; COLD maps only RARS's
    # first page (the root tables' page, its boot map entry)
    vm = [p for p in range(sym('OS_PAGE_END') >> 10, sym('VM_TABLES_END') >> 10)
          if p in ld.vmap and p != sym('RARS') >> 10]
    r.check(not vm, '%d pages of the VM tables\' windows mapped by COLD'
            % len(vm))
    r.check(ld.vmap.get(sym('RARS') >> 10) == 0x4001C00 >> 10,
            'RARS is not mapped at the root table\'s page')
    r.note('file 0x%X bytes = COLD 0x%X + DUMP 0x%X + the kernel to RELOC '
           '0x%X (low 0x%X); boot map at 0x%X; the kernel %d pages to '
           'OS_PAGE_END 0x%X' % (len(img.d), COLD9_SIZE, DUMP9_SIZE, reloc,
                                 reloc_low, at, ld.kernel_pages,
                                 sym('OS_PAGE_END')))
    r.show()
    return not r.errors


def main():
    global SAU
    ap = argparse.ArgumentParser()
    ap.add_argument('--sau', type=int, default=2, choices=SAUS,
                    help='the SAU whose image and COLD this is (default 2)')
    ap.add_argument('--map', help='the original\'s link map: check the '
                    'oracle\'s loader against its file segments')
    ap.add_argument('--image', required=True)
    ap.add_argument('--elf', required=True)
    ap.add_argument('--orig')
    ap.add_argument('--segments')
    ap.add_argument('--ref')
    ap.add_argument('--write-segments', metavar='OUT',
                    help='--sau 9: write the oracle json (the header and '
                    'the boot map) from --orig and --map, and stop')
    a = ap.parse_args()
    select_sau(a.sau)
    if SAU == 9 and a.write_segments:
        img = Image9(a.orig)
        hdr = header9(img)
        at, _ = map_segment(a.map, 'OS_COLD')
        seg = dict(source='sr10.2-install/install/ri.apollo.os.v.10.2/sau9/'
                   'domain_os (written by tools/check_rfc.py --sau 9 '
                   '--write-segments)',
                   header={k: hex(v) for k, v in hdr.items()},
                   boot_map=[dict(at=hex(e['at']), phys=hex(e['phys']),
                                  va=hex(e['va']), count=e['count'],
                                  flags=hex(e['flags']))
                             for e in boot_map(img, at)])
        with open(a.write_segments, 'w') as f:
            json.dump(seg, f, indent=1)
            f.write('\n')
        return 0
    if SAU == 9:
        # another form of RFC image (its own checks, above)
        ok = True
        if a.orig:
            ok = check_orig9(a)
        return 0 if check_ours9(a) and ok else 1
    ok = True
    below = None
    if a.orig:
        if not os.path.exists(a.orig):
            print('check_rfc: the original image %s is missing (set '
                  'SAU2_IMAGE or SAU_IMAGE)' % a.orig, file=sys.stderr)
            return 1
        ok_o, below = check_orig(a)
        ok = ok and ok_o
    ok = check_ours(a, below) and ok
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
