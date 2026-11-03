#!/usr/bin/env python3
#
# tools/gen_layout_ld.py - lay the kernel's code and module data blocks out
# in the order of the SAU2 link map, or of another SAU's map (--sau N)
#
# One generator for every SAU, as tools/asm_compare.py: --sau N (default 2)
# picks the address tables (keyed by SAU, below) for the map given with
# --map; `make TARGET_SAU=sau5 check-layout' passes the SAU5's.  The text
# below describes the SAU2; the SAU5's tables carry their map lines.
#
# Absolute addresses do not have to match the image; the RELATIVE
# PLACEMENT does.  Code and data are linked in the order the SAU2 link map
# (domain_os.10.2.map, the map of the SR10.2 SAU2 image) gives them, so a
# data block that follows its
# module's code in the image follows it in our link too, and modules come in
# the image's sequence.  Nothing is placed at a fixed address.
#
# The kernel is built from Domain Pascal.  dpc emits one input section per map
# module and section: `.text.<MODULE>.<SECTION>' (plain `.text' for the
# module's default section) and `.moddata.<MODULE>[.<SECTION>]' /
# `.bss.moddata.<MODULE>[.<SECTION>]' for its data block; the hand-written
# assembly gives each routine a `.section ".text.<symbol>"' where that leaves
# its bytes intact.  A data block is keyed by its module's data segment of the
# map (dpc_blocks), the ORDERING KEY, not a placement.
#
# This script reads the map into an address-ordered stream, finds every
# code section of the link inputs and the map position of the symbols it
# defines, merges in the module data blocks at their declared addresses,
# and writes the fragments that kernel.ld INCLUDEs:
#   build/sau2/layout.ld       inside `.text': the ordered list of
#                              input-section statements (code, C data and
#                              blocks), followed by a catch-all, which is
#                              empty;
#   build/sau2/layout_data.ld  at the end of `.data': C bss objects left
#                              unplaced as zero bytes in the file (none);
#   build/sau2/layout_bss.ld   inside the NOBITS `.bss': the image's own bss
#                              (the bss rule below), in map order, up to the
#                              VM tables' run-time windows;
#   build/sau2/layout_vm.ld    inside the NOBITS `.vm_tables' past
#                              OS_PAGE_END: the run-time windows of the map's
#                              VM_TABLES (AREA_$RPMAP_CACHE, MST, PIT_PAGES,
#                              MSTE_PAGES .. VM_TABLES_END), at the map's
#                              offsets from AREA_$RPMAP_CACHE.
# The first and third also define, at their map positions, the section
# boundaries OS_$INIT builds the address space from (TEXT_MARKS, BSS_MARKS),
# and layout.ld names the start of the catch-all
# (OS_LINK_UNPLACED).
#
# Placement rules:
#   - A code section defining one or more map symbols is keyed by the
#     earliest of them (map address, then map line).
#   - A module data block is keyed by its declared address, ahead of any
#     map symbol at the same address.
#   - A few sections hold image data under C names the map does not use;
#     ANCHORS below keys them by their image address.
#   - A section whose map symbols straddle another placed section's key
#     (or a block's) would put the two out of order whatever we do; that
#     is an error naming the section, which must be split, one section per
#     routine.
#   - C .rodata/.data/.bss objects (-fdata-sections) are placed the same
#     way: by the map symbol they define (DI_$Q_HEAD, which the map puts
#     inside a hand-written block, trails that block), else by
#     DATA_ANCHORS (image data under a C name of ours).  A bss object keyed
#     in the image's bss is NOBITS there; every other one is file zeros at
#     its position.
#   - Everything else -- file-static helpers, C objects under names of
#     ours, const cells -- is placed by its OWNER, the referencing section
#     in the most resident place (the rules are at
#     SPECIAL_PAIRS / _key_by_owner below): code and const data trail the
#     owner, writable data goes to the owner module's data segment of the
#     map, so a wired module's private code and data are wired and an
#     unwired one's are paged, as in the image.  Anything with no owner
#     sits, wired, where the image's run-time helpers (M$ARITH) end.
#     Nothing is left to a catch-all.  (libgcc.a is not linked at all.)
#   - The map's windows past OS_DATA_END that no object fills (STACK,
#     OS_PMAPS, AST_AOT, AST_PMAPS: BSS_WINDOWS) are laid out in `.bss'
#     at their map positions by their map symbols, and the Pascal's overlay
#     sections (`var (name)', dpc's COMMON symbols) are defined at the map
#     segment of their name with its size.
#
# Modes:
#
#   gen_layout_ld.py [--sau N] --map MAP -o build/sau2/layout.ld OBJ...
#       Scan, check and write the four fragments (layout_data.ld,
#       layout_bss.ld and layout_vm.ld next to layout.ld; each only if its
#       text changed).
#
#   gen_layout_ld.py --map MAP --check-only OBJ...
#       The same checks, no output.
#
#   gen_layout_ld.py --map MAP --check-elf ELF OBJ...
#       After a scratch link: every placed map symbol, every ANCHORS section
#       (by its first symbol), every block and the map symbols of the C bss
#       objects in the image's bss must appear in the ELF in map order; the
#       first inversion fails the check.  So must the marks, the window
#       symbols (each at its map offset from the window's first) and the
#       overlay sections; and every map symbol at a fixed VA (below
#       OS_BEGIN + 0x400, or from IODEFS up: the SAU's script's and iodefs.s's
#       absolute symbols) the ELF defines must have the map's value.  The
#       first item placed at or past each numbered map section that starts
#       a page (page_sections) must start a page.
#       Prints how many map symbols were placed and what fell into the
#       catch-all.
#
# Checks that fail the build: a dpc block whose module has no single data
# segment in its section of the map; an odd block address; the same block
# name defined twice; an ANCHORS section that no longer exists; a COMMON
# symbol with no map segment or symbol of its name, or larger than its
# segment; anything keyed inside a BSS_WINDOWS window.  A block address
# inside no map segment is a warning naming the nearest segment.

import argparse
import bisect
import os
import re
import struct
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rfc_elf  # noqa: E402

# The SAU whose map and layout this run reads (--sau; 2 by default).  Every
# address table below is keyed by SAU first, as in tools/asm_compare.py:
# NAME[2] is the SAU2's (domain_os.10.2.map), NAME[5] the SAU5's
# (sr10.2-install/.../sau5/domain_os.map), each entry the map address with
# its map line as the evidence.  The SAU3 and SAU5 are laid out like the
# SAU2 (the same RFC load address, kernel offset and kernel VA), only the
# addresses differ.
SAU = 2
SAUS = (2, 3, 5, 8, 9)

# OS_BEGIN: the bottom of the kernel's VAs (`D95 E00000 OS_BEGIN' on both)
RFC_LOAD_ADDR = {2: 0x00E00000, 3: 0x00E00000, 5: 0x00E00000,
                 8: 0x03C00000,   # D00 3C00000 OS_BEGIN
                 9: 0x3C400000}   # D98 3C400000 OS_BEGIN
# 24-bit physical/virtual space of the SAU2 and the SAU5
KERNEL_VA_END = {2: 0x01000000, 3: 0x01000000, 5: 0x01000000,
                 8: 0x04000000,   # the SAU8's 26-bit space (MMU 3FFB400)
                 9: 0x40000000}   # the SAU9's 30-bit space (PROM 3FFE0000)
# Map addresses below FIXED_LOW_END that are not fixed: the SAU9's OS_COLD
# module (os/cold.pas: its data and code, `D 4002FFC OS_COLD' and `I
# 4003068 OS_COLD size = 568'), compiled code laid out after COLD_START in
# kernel.ld's `.cold'.
FIXED_EXEMPT = {2: [], 3: [], 5: [], 8: [], 9: [(0x04002FFC, 0x040035D0)]}
# The fixed VAs from OS_BEGIN up (check_elf compares them with the map):
# the crash record page; on the SAU9 also the trap page (OS_BEGIN +
# 0x1000, `trap_page_high'), up to DUMP.
FIXED_LOW_END = {2: 0x00E00400, 3: 0x00E00400, 5: 0x00E00400,
                 8: 0x03C00400,   # D24 3C00400 DUMP
                 9: 0x3C401400}   # D24 3C401400 DUMP

# The image's RELOC (map `I20 E88834 RELOC'): the first byte after the last
# loaded segment.  Everything the map places at or past it (ACL_$DATA,
# FILE_$LOT_DATA, RINGLOG_$DATA, ..., OS_PMAPS, VM_TABLES) had no bytes in
# the image file; it is the image's bss.
# The bss rule of this layout follows it exactly:
#   - a zero-filled block (a `.bss.moddata.<name>'
#     NOBITS input) whose ordering key is in [IMAGE_BSS_START,
#     IMAGE_BSS_END), and a C bss object (`.bss.<symbol>') whose map symbols
#     all lie there, go to the NOBITS `.bss' output section, in map order
#     (build/sau2/layout_bss.ld), after the fixup table;
#   - every other zero-filled block stays among the code at its map
#     position as zero bytes in the file (the image had those zeros in the
#     file: PROC1_$DATA, PEB_$INFO, ...), and every other C bss object
#     (no map symbol, or one outside that range) is zero bytes in the
#     file after the initialised data (build/sau2/layout_data.ld), so the
#     C code's assumption that its bss starts zeroed holds for everything
#     the image itself had zeroed in the file.
# Since every key >= IMAGE_BSS_START is past every key of the loaded
# stream, the map order of the whole link is unchanged and `--check-elf'
# checks the NOBITS part with the rest.
IMAGE_BSS_START = {
    2: 0x00E88834,      # I20 E88834 RELOC
    3: 0x00E8A434,      # I20 E8A434 RELOC
    5: 0x00E92834,      # I20 E92834 RELOC
    8: 0x03CA65F8,      # I21 3CA65F8 RELOC
    9: 0x3C4A75D8,      # I21 3C4A75D8 RELOC
}
# ... up to the map's IODEFS_GUARD (`D52 F4FC00', the end of the kernel's
# wired VAs, OS_WIRED_END in os/init.c).  Map symbols past it (AST_$COPY_BUFF
# 0xFF8800, AST_$ZERO_BUFF 0xFF8C00, ...) are absolute addresses outside
# the image: I/O pages and mapping windows, defined as absolute symbols by
# arch/m68k/sau2/iodefs.s (a window must be its own page).
IMAGE_BSS_END = {
    2: 0x00F4FC00,      # D52 F4FC00 IODEFS_GUARD
    3: 0x00F4FC00,      # D56 F4FC00 IODEFS_GUARD
    5: 0x00F48000,      # D55 F48000 IODEFS_GUARD
    8: 0x03F2E000,      # D62 3F2E000 IODEFS_GUARD
    9: 0x3E52C000,      # D58 3E52C000 IODEFS_GUARD
}
# The map's I/O space from IODEFS up: fixed VAs, like everything below
# OS_BEGIN + 0x400 (check_elf compares both with the map).
FIXED_IO_START = {
    2: 0x00FC0000,      # FC0000 IODEFS (= DISP1_MEM)
    3: 0x00FC0000,      # FC0000 IODEFS (no display memory there)
    5: 0x00F90000,      # F90000 IODEFS (= KOLOR_CTL)
    8: 0x03FA0000,      # 3FA0000 IODEFS (= DISP1_MEM)
    9: 0x3FF97C00,      # 3FF97C00 IODEFS (= RING_8025_2)
}

# The run-time windows of the map's VM_TABLES.  The image's COLD maps the
# kernel only up
# to its OS_PAGE_END (0xEC4800); everything past it gets pages at run time.
# AST_$AOT and AST_PMAPS (PMAP_$SEGMAP) are filled on demand by
# AST_$ADD_AOTES / AST_$ADD_ASTES, which install a page only where
# MMU_$VTOP finds none (0x00E0104C, 0x00E011C4, 0x00E0126C, 0x00E012CA), so
# they stay in `.bss' and COLD maps them; from AREA_$RPMAP_CACHE (= the
# map's AST_PMAPS_END) up the kernel installs fresh pages unconditionally
# (AREA_$INIT 0x00E2F48A, MST_$INIT 0x00E30AE2 for MST and the MSTE pages,
# area_$alloc_seg_table 0x00E09D90 for PIT_PAGES), so those VAs must not be
# mapped by COLD: they go to the NOBITS `.vm_tables' that kernel.ld starts at
# OS_PAGE_END, in map order and at the map's offsets from its first symbol.
# Keys in [VM_WINDOWS_START, IMAGE_BSS_END) go there; each VM_WINDOW_MARKS
# name is defined (`NAME = .;') at its map offset.  No link input defines
# any of them (mst/mst_internal.ins.pas has `mst: extern'): they are the
# map's symbols of `D ED5000 VM_TABLES size = 7AC00' from VM_WINDOWS_START
# up (its part below, AST_PMAPS, is a BSS_WINDOWS entry).
#
# The SAU9's COLD (os/cold.pas OS_$COLD_START) maps the kernel up to the
# map's OS_PAGE_END, which lies inside the OS_PMAPS window (`D 3C4D4800
# OS_PMAPS size = ECA000': MMAP, the global page maps, SMAPS, and from
# SMAPS + 0x3B800 = OS_PAGE_END the rest of SMAPS and RARS); everything
# from there to IODEFS_GUARD (the rest of OS_PMAPS, AUDIT_LIST, AST_AOT,
# VM_TABLES) gets pages at run time, so the SAU9's windows start at
# OS_PAGE_END, and its marks are every map symbol from there on.
VM_WINDOWS_START = {
    2: 0x00EE4C00,      # EE4C00 AREA_$RPMAP_CACHE
    3: 0x00EE4C00,      # EE4C00 AREA_$RPMAP_CACHE
    5: 0x00EDD000,      # EDD000 AREA_$RPMAP_CACHE
    8: 0x03CF6400,      # 3CF6400 OS_PAGE_END
    9: 0x3C650800,      # 3C650800 OS_PAGE_END
}
VM_WINDOW_MARKS = {}
VM_WINDOW_MARKS[2] = VM_WINDOW_MARKS[3] = VM_WINDOW_MARKS[5] = [
    'AREA_$RPMAP_CACHE', 'AST_PMAPS_END', 'MST', 'PIT_PAGES', 'MSTE_PAGES',
    'VM_TABLES_END']
    # sau2: EE4C00, EE4C00, EE5800, EE6400, EF6400, F4FC00
    # sau3: the SAU2's
    # sau5: EDD000, EDD000, EDDC00, EDE800, EEE800, F48000
VM_WINDOW_MARKS[9] = [
    'OS_PAGE_END', 'SMAPS_END', 'RARS', 'RARS_END', 'AST', 'AOT',
    'AST_PMAPS', 'VM_TABLES', 'AREA_$RPMAP_CACHE', 'AST_PMAPS_END', 'BST',
    'MST', 'PIT_PAGES', 'MSTE_PAGES', 'VM_TABLES_END']
    # 3C650800, 3D390000 (SMAPS_END = RARS), 3D39E800 (RARS_END, AUDIT_LIST),
    # 3D39F400 (AST_AOT), 3D3C6A00, 3D402C00 (VM_TABLES), 3D4B6C00 (=
    # AST_PMAPS_END), 3D4B7800, 3DB75000, 3DB82800, 3DB92800, 3E52C000
# The SAU8's as the SAU9's (COLD maps the kernel up to OS_PAGE_END, SMAPS +
# 0x3400 inside OS_PMAPS), but its AST and AOT are in the low region
# (`D05 3AC3800 AST_AOT', below OS_BEGIN).
VM_WINDOW_MARKS[8] = [
    'OS_PAGE_END', 'SMAPS_END', 'RARS', 'RARS_END', 'AST_PMAPS',
    'VM_TABLES', 'AREA_$RPMAP_CACHE', 'AST_PMAPS_END', 'BST', 'MST',
    'PIT_PAGES', 'MSTE_PAGES', 'VM_TABLES_END']
    # 3CF6400, 3DAF800 (SMAPS_END = RARS), 3DB6C00 (RARS_END, AUDIT_LIST),
    # 3DB7800 (VM_TABLES = AST_PMAPS), 3DE7800 (= AST_PMAPS_END),
    # 3DE8400, 3E4DC00, 3E51400, 3E61400, 3F2E000

# The map's data segments past OS_DATA_END that no object fills: the
# binder's windows, segments of modules with no code and no file bytes
# (`D EB0000 STACK', `D EB4800 OS_PMAPS', the two `D VM_TABLES' below
# VM_WINDOWS_START).  Nothing in the Pascal tree or the hand assembly
# defines them.
# Each is laid out in `.bss' (layout_bss.ld) at its map position among the
# other NOBITS items, page aligned where the map's address is, and every
# map symbol inside it is defined at the map's offset from its first one;
# the window then takes its map size.  So the consumers (COLD, OS_$INIT,
# MMAP_$INIT, the MMU, AST and stack code) name the map's symbols:
#   (map address, the segment's module name, map symbols at its end that
#    belong to it, a note)
BSS_WINDOWS = {}
BSS_WINDOWS[2] = [
    # D64 EB0000 PAGE / D EB0000 STACK size = 2C00: NULL_STACK_GUARD,
    # NULL_STACK, NULL_PC, P1_STACK_GUARD, INT_STACK_GUARD = P1_STACK_BASE
    # (COLD's initial SP, 0x1016F8); INT_STACK_BASE is its end (the map
    # lists it under `D65 EB2C00 VTOC_CACHE').  OS_PAGE, the same address,
    # is a BSS_MARKS mark.
    (0x00EB0000, 'STACK', ['INT_STACK_BASE']),
    # D42 EB4800 OS_PMAPS size = 10000: MMAP (the MMAPE table, which COLD
    # clears, 0x1015F8) and MMU_$PTTX 0xEC2800 (COLD 0x101768).
    (0x00EB4800, 'OS_PMAPS', []),
    # D00 EC5400 AST_AOT / D EC5400 VM_TABLES size = F960: AST, AOT.
    (0x00EC5400, 'VM_TABLES', []),
    # D98 ED5000 VM_TABLES size = 7AC00: here only AST_PMAPS (and the
    # map's VM_TABLES symbol), up to VM_WINDOWS_START = AST_PMAPS_END; the
    # rest is layout_vm.ld.
    (0x00ED5000, 'VM_TABLES', []),
]
# The SAU3's are the SAU2's, at the same addresses (its map's `D68 EB0000
# PAGE' / `D EB0000 STACK size = 2C00' with INT_STACK_BASE under `D69
# EB2C00 VTOC_CACHE', `D46 EB4800 OS_PMAPS size = 10000', `D01 EC5400
# AST_AOT' / `D EC5400 VM_TABLES size = F960', `D99 ED5000 VM_TABLES size
# = 7AC00').
BSS_WINDOWS[3] = [
    (0x00EB0000, 'STACK', ['INT_STACK_BASE']),
    (0x00EB4800, 'OS_PMAPS', []),
    (0x00EC5400, 'VM_TABLES', []),
    (0x00ED5000, 'VM_TABLES', []),
]
# The SAU5 has no AST_AOT window in the kernel: its `D00 DA6400 AST_AOT' /
# `D DA6400 VM_TABLES size = F960' (AST, AOT) is in the low region below
# OS_BEGIN, fixed VAs like AREA_PAGES (the linker script's).
BSS_WINDOWS[5] = [
    # D67 EB8000 PAGE / D EB8000 STACK size = 2C00: NULL_STACK_GUARD ..
    # INT_STACK_GUARD = P1_STACK_BASE 0xEBA000; INT_STACK_BASE is its end
    # (the map lists it under `D68 EBAC00 VTOC_CACHE').
    (0x00EB8000, 'STACK', ['INT_STACK_BASE']),
    # D45 EBC800 OS_PMAPS size = 10000: MMAP, MMU_$PTTX 0xECA800.
    (0x00EBC800, 'OS_PMAPS', []),
    # D98 ECD400 VM_TABLES size = 7AC00: here only AST_PMAPS (and the
    # map's VM_TABLES), up to VM_WINDOWS_START = AST_PMAPS_END 0xEDD000.
    (0x00ECD400, 'VM_TABLES', []),
]
# The SAU9's: the stacks page and the part of OS_PMAPS below its
# OS_PAGE_END (VM_WINDOWS_START: the rest is layout_vm.ld's).
BSS_WINDOWS[9] = [
    # D69 3C4D0000 PAGE / D 3C4D0000 STACK size = 2C00: NULL_STACK_GUARD ..
    # INT_STACK_GUARD = P1_STACK_BASE 0x3C4D2000; INT_STACK_BASE is its end
    # (the map lists it under `D70 3C4D2C00 VTOC_CACHE').
    (0x3C4D0000, 'STACK', ['INT_STACK_BASE']),
    # D49 3C4D4800 OS_PMAPS size = ECA000: here MMAP, OS_PMAPS, OS_PMAP0,
    # OS_PMAP_SPECIAL, OS_PMAP_END and SMAPS, up to OS_PAGE_END 0x3C650800.
    (0x3C4D4800, 'OS_PMAPS', []),
]
# The SAU8's: the stacks page and OS_PMAPS below its OS_PAGE_END, as the
# SAU9's.
BSS_WINDOWS[8] = [
    # D73 3CC8000 PAGE / D 3CC8000 STACK size = 2C00: NULL_STACK_GUARD ..
    # INT_STACK_GUARD = P1_STACK_BASE 0x3CCA000; INT_STACK_BASE is its end
    # (the map lists it under `D74 3CCAC00 VTOC_CACHE').
    (0x03CC8000, 'STACK', ['INT_STACK_BASE']),
    # D52 3CCC800 OS_PMAPS size = EA400: here MMAP, OS_PMAPS, OS_PMAP0,
    # OS_PMAP_SPECIAL, OS_PMAP_END and SMAPS, up to OS_PAGE_END 0x3CF6400.
    (0x03CCC800, 'OS_PMAPS', []),
]
# Overlay sections in the low region below OS_BEGIN, fixed VAs that the
# SAU's script defines (sau9.ld: the Ethernet's and the 802.5 ring's
# buffers, `D53 3C06F800 ETHERNET_$BUFFER', `D64 3C070800
# RING8025_$AUX_DA'); the layout leaves them alone.
# The SAU3's: the internet interface controller's lines' control pages
# (`D89 D65C00 IIC_$CONTROL_PAG size = 2000', iic/iic.pas), in sau3.ld.
LOW_OVERLAYS = {2: set(), 3: {'IIC_$CONTROL_PAG'}, 5: set(),
                8: {'ETHERNET_$BUFFER', 'RING8025_$AUX_DA'},
                9: {'ETHERNET_$BUFFER', 'RING8025_$AUX_DA'}}
# Overlay sections in the VM tables' windows (layout_vm.ld): the SAU9's
# AUDIT_LIST (`D91 3D39E800 AUDIT_LIST size = C00') lies past its
# OS_PAGE_END; the SAU2's and SAU5's overlays are all below theirs.
VM_OVERLAYS = {2: False, 3: False, 5: False, 8: True, 9: True}
# Map names inside the windows that something else defines.
BSS_WINDOW_SKIP = {'OS_PAGE', 'OS_PAGE_END'}

# Input sections kernel.ld places itself (output sections of their own at
# fixed VMAs): COLD (.cold, 0x101400, file 0) and the DUMP page (.dump,
# 0xE00400, file 0x800).  The fragments list them as comments only.  (The
# crash record page, `.crash_record' at OS_BEGIN, NOBITS, holds no input
# section: kernel.ld defines CRASH_$RECORD and LOG_$LAST_ENTRY there
# itself.)
SCRIPT_PLACED = {
    '.text.COLD',
    '.text.DUMP',
    # the SAU9's OS_COLD module (os/cold.pas), in `.cold' after COLD_START
    '.text.OS_COLD.COLD_PROC',
    '.moddata.OS_COLD.COLD',
}

PAGE = 0x400

# Map symbols the link defines at their map position: the section
# boundaries OS_$INIT builds the kernel's address space from.  Each is
# emitted
# as `NAME = .;' just before the first placed item whose ordering key is at
# or past the map address (or at the end of the stream if none is), after
# `. = ALIGN(n)' when the image's binder started that segment on an n-byte
# boundary.  OS_$INIT rounds .TEXT's start down and OS_DATA_END up to a
# 32 KB segment at run time (`andi.l #-0x8000' at 0x00E339A2..0x00E339DC),
# so those two must be segment aligned here as they are in the image, or
# the rounding would hand wired pages to the paging loop (0x00E34426) and
# have it free the stacks and MMAP; the page alignments reproduce the
# binder's segment starts that the type-4 protection walk (0x00E33B88)
# and the keep-wired test (0x00E3450A) round to a page.  os_$start_proc2
# frees OS_INIT_START .. OS_INIT_END rounded up to a segment (0x00E6D25C)
# page by page without rounding the start, so OS_INIT_START starts a page
# as the binder's OS_INIT_PROC segment did.
#   (map address, symbol, alignment or None)  -- map line
TEXT_MARKS = {}
TEXT_MARKS[2] = [
    (0x00E1DC00, 'OS_DATA_WIRED', PAGE),      # D24 E1DC00 WIRED_DATA
    # The dynamic DCTE area, empty on the SAU2: three zero-size sections,
    # `D44 E2E0A0 DCTE_START', `D45 E2E0A0 DCTES', `D43 E2E0A0 DCTE_END',
    # at the start of `D28 E2E0A0 NET_PORT_TABLE'; IO_'s block holds both
    # addresses (io/io.pas +0x544/+0x548, image 00E2E0A0 00E2E0A0).
    (0x00E2E0A0, 'DCTE_START', None),         # D44 E2E0A0 DCTE_START
    (0x00E2E0A0, 'DCTE_END', None),           # D43 E2E0A0 DCTE_END
    (0x00E2F000, 'OS_INIT_START', PAGE),      # I 5 E2F000 OS_INIT_PROC
    (0x00E35380, 'OS_INIT_END', None),        # E35380 OS_INIT_END (after
                                              # D E3537C SMD)
    (0x00E38000, 'OS_PROC_UNWIRED', 0x8000),  # I 1 E38000 .TEXT
    (0x00E3E746, 'OS_DISK_PROC_END', None),   # I E3E744 OS_DISK_END
    # Wired-range bounds whose image values sit in literal cells that
    # MST_$WIRE_AREA takes by address: OS_$SHUTDOWN's
    # 0x00E6D688..0x00E6D697, PEB_$LOAD_WCS's 0x00E322DC..0x00E322EB,
    # NETLOG_$CNTL's 0x00E71B28..0x00E71B37, STOP_$DATA's wire_end and
    # ROUTE_$WIRE_ROUTING_AREA's 0x00E69C04.  Each range's start that is a
    # linked object's first byte uses that object (OS_PROC_SHUTWIRED,
    # NETLOG_$CNTL, STOP_$WATCH) where the code names the object; the
    # Pascal names the map's own start symbols (`extern char':
    # PEB_$WIRED_DATA_START, NETLOG_$PROC_START, NETLOG_$DATA_START,
    # AUDIT_$PROC_START, AUDIT_$DATA_START), which are marks here too.
    (0x00E6D6FE, 'OS_PROC_SHUTWIRED_END', None),  # I E6D6FC OS_SHUTWIRED_END
    (0x00E70810, 'PEB_$WIRED_PROC_START', None),  # I E70810 PEB_WIRED
    (0x00E70A3E, 'PEB_$WIRED_PROC_END', None),    # I E70A3C PEB_WIRED_END
    # AUDIT's code range (audit/audit.pas; the map's I E70AFC AUDIT size =
    # E14, then the 4 zero bytes of I E71910 AUDIT with the end at +2, as
    # the other *_END segments), and NETLOG's start (its first routine,
    # NETLOG_$CNTL, netlog/netlog.ins.pas).
    (0x00E70AFC, 'AUDIT_$PROC_START', None),      # I E70AFC AUDIT
    (0x00E71912, 'AUDIT_$PROC_END', None),        # I E71910 AUDIT (size 4)
    (0x00E71914, 'NETLOG_$PROC_START', None),     # I E71914 NETLOG
    (0x00E71D7A, 'NETLOG_$PROC_END', None),       # I E71D78 NETLOG (size 4)
    (0x00E75400, 'RING_PROC_START', PAGE),    # I 8 E75400 RING_PROC / D58
                                              # RING_PROC_START
    (0x00E77F34, 'RING_PROC_END', None),      # D57 E77F34 RING_PROC_END
    (0x00E78400, 'OS_DATA_UNWIRED', PAGE),    # D21 E78400 .DATA (= OS_DATA)
    (0x00E784D0, 'OS_DISK_DATA', None),       # D E784D0 VTOC_
    (0x00E7B044, 'OS_DISK_DATA_END', None),   # D E7B044 SVC_CATCHER
    (0x00E82128, 'OS_DATA_SHUTWIRED', None),      # D E82128 FILE_
    (0x00E82740, 'OS_DATA_SHUTWIRED_END', None),  # D E82740 DTTY_ASM
    # The wired data ranges of PEB, AUDIT and NETLOG (peb/peb.ins.pas,
    # netlog/netlog.ins.pas), the bounds of three adjacent data segments
    # of the map, `D E84E80 PEB_WIRED size = 658', `D E854D8 AUDIT size =
    # 1AC', `D E85684 NETLOG size = 84', each end the next one's start.
    (0x00E84E80, 'PEB_$WIRED_DATA_START', None),  # D E84E80 PEB_WIRED
    (0x00E854D8, 'PEB_$WIRED_DATA_END', None),    # D E854D8 AUDIT
    (0x00E854D8, 'AUDIT_$DATA_START', None),      # D E854D8 AUDIT
    (0x00E85684, 'AUDIT_$DATA_END', None),        # D E85684 NETLOG
    (0x00E85684, 'NETLOG_$DATA_START', None),     # D E85684 NETLOG
    (0x00E85708, 'NETLOG_$DATA_END', None),       # D E85708 DXM_WIRED_
    (0x00E86400, 'RING_DATA_START', PAGE),    # D30 E86400 RING_DATA / D56
                                              # RING_DATA_START
    (0x00E869D0, 'RING_DATA_END', None),      # D55 E869D0 RING_DATA_END
    (0x00E87000, 'RTWIRED_PROC_START', PAGE),  # I12 E87000 RTWIRED_CODE
    # The end of the wired routing data (route/route.ins.pas; the end of
    # `D E87D80 ROUTE_RTWIRED size = 4A8' in D34 RTWIRED_DATA) and of PBU's
    # wired data (the end of `D E88460 EC2_PBU size = 300' in D86
    # PBU_WIRED_DATA).
    (0x00E88228, 'RTWIRED_DATA_END', None),   # E88228 RTWIRED_DATA_END
    (0x00E88760, 'PBU_$DATA_END', None),      # E88760 PBU_$DATA_END
]
# The SAU5's: the same marks at its map's addresses (each a map symbol
# there, except OS_PROC_UNWIRED, OS_DATA_WIRED, OS_DATA_UNWIRED and
# RING_*, named after the map's segments as on the SAU2), and the marks of
# the SAU5's own wired-on-demand ranges, which its Pascal names (`extern
# char') for MST_$WIRE_AREA: SM_$PROC_START / SM_$DATA_START /
# SM_$DATA_END (sm/sm.ins.pas), SM_C_$PROC_START (sm_c), MT_$PROC_START
# (mt/mt.ins.pas), CT_$PROC_START / CT_$DATA_START / CT_$DATA_END
# (ct/acquire.pas), each the first byte of a module's code or data
# segment (or the next one's) as NETLOG_$PROC_START is; and
# PBU_$PAGE_END, which labels pbu/map_check_unit.pas's routine (module-
# local, no map name of its own).  The *_END marks of code ranges that
# the hand assembly defines (SM_$PROC_END, MT_$PROC_END, ...: the
# `*_END_ADDR' segments) are not marks.
TEXT_MARKS[5] = [
    (0x00E1E800, 'OS_DATA_WIRED', PAGE),      # D24 E1E800 WIRED_DATA
    (0x00E2F4C4, 'DCTE_START', None),         # D47 E2F4C4 DCTE_START
    (0x00E2F4C4, 'DCTE_END', None),           # D46 E2F4C4 DCTE_END
    (0x00E30400, 'OS_INIT_START', PAGE),      # I 5 E30400 OS_INIT_PROC
    (0x00E37B8C, 'OS_INIT_END', None),        # E37B8C OS_INIT_END (after
                                              # D E37B88 SMD)
    (0x00E38000, 'OS_PROC_UNWIRED', 0x8000),  # I 1 E38000 .TEXT
    (0x00E3DE7A, 'OS_DISK_PROC_END', None),   # I E3DE78 OS_DISK_END
    (0x00E6EE58, 'SM_$PROC_START', None),     # I E6EE58 SM
    (0x00E6F97A, 'OS_PROC_SHUTWIRED_END', None),  # I E6F978 OS_SHUTWIRED_END
    (0x00E746FC, 'PEB_$WIRED_PROC_START', None),  # I E746FC PEB_WIRED
    (0x00E7492A, 'PEB_$WIRED_PROC_END', None),    # I E74928 PEB_WIRED_END
    (0x00E74934, 'SM_C_$PROC_START', None),       # I E74934 SM_C
    (0x00E76B48, 'MT_$PROC_START', None),         # I E76B48 MT_$SIO
    (0x00E76EAC, 'CT_$PROC_START', None),         # I E76EAC CT
    (0x00E77C70, 'AUDIT_$PROC_START', None),      # I E77C70 AUDIT
    (0x00E78A86, 'AUDIT_$PROC_END', None),        # I E78A84 AUDIT (size 4)
    (0x00E78A88, 'NETLOG_$PROC_START', None),     # I E78A88 NETLOG
    (0x00E78EEE, 'NETLOG_$PROC_END', None),       # I E78EEC NETLOG (size 4)
    (0x00E7C800, 'RING_PROC_START', PAGE),    # I 8 E7C800 RING_PROC / D61
                                              # RING_PROC_START
    (0x00E7F1B4, 'RING_PROC_END', None),      # D60 E7F1B4 RING_PROC_END
    (0x00E7F800, 'OS_DATA_UNWIRED', PAGE),    # D21 E7F800 .DATA (= OS_DATA)
    (0x00E7F8D0, 'OS_DISK_DATA', None),       # D E7F8D0 VTOC_
    (0x00E82308, 'OS_DISK_DATA_END', None),   # D E82308 SVC_CATCHER
    (0x00E89444, 'OS_DATA_SHUTWIRED', None),      # D E89444 FILE_
    (0x00E89A5C, 'SM_$DATA_START', None),         # D E89A5C SM
    (0x00E89AB8, 'OS_DATA_SHUTWIRED_END', None),  # D E89AB8 DTTY_ASM
    (0x00E89AB8, 'SM_$DATA_END', None),           # D E89AB8 DTTY_ASM
    # PEB_WIRED, then CT's data segment (`D E8CFEC CT size = D18'), then
    # AUDIT and NETLOG: on the SAU5 PEB's end is not AUDIT's start.
    (0x00E8C994, 'PEB_$WIRED_DATA_START', None),  # D E8C994 PEB_WIRED
    (0x00E8CFEC, 'PEB_$WIRED_DATA_END', None),    # D E8CFEC CT
    (0x00E8CFEC, 'CT_$DATA_START', None),         # D E8CFEC CT
    (0x00E8DD04, 'CT_$DATA_END', None),           # D E8DD04 AUDIT
    (0x00E8DD04, 'AUDIT_$DATA_START', None),      # D E8DD04 AUDIT
    (0x00E8DEB0, 'AUDIT_$DATA_END', None),        # D E8DEB0 NETLOG
    (0x00E8DEB0, 'NETLOG_$DATA_START', None),     # D E8DEB0 NETLOG
    (0x00E8DF34, 'NETLOG_$DATA_END', None),       # D E8DF34 DXM_WIRED_
    (0x00E8EC00, 'RING_DATA_START', PAGE),    # D30 E8EC00 RING_DATA / D59
                                              # RING_DATA_START
    (0x00E8F1D0, 'RING_DATA_END', None),      # D58 E8F1D0 RING_DATA_END
    (0x00E8F800, 'RTWIRED_PROC_START', PAGE),  # I12 E8F800 RTWIRED_CODE
    (0x00E90A28, 'RTWIRED_DATA_END', None),   # E90A28 RTWIRED_DATA_END
    (0x00E91F70, 'PBU_$PAGE_END', None),      # E91F70 PBU_$PAGE_END (I16
                                              # E91F70 PBU_WIRED_PROC)
    (0x00E92728, 'PBU_$DATA_END', None),      # E92728 PBU_$DATA_END
]
# The SAU3's: the SAU2's marks at its map's addresses (each a map symbol
# there, except OS_PROC_UNWIRED, OS_DATA_WIRED, OS_DATA_UNWIRED and RING_*,
# as on the SAU2), and the marks of the SAU3's own wired-on-demand ranges
# its Pascal names (`extern char') for MST_$WIRE_AREA: SM_$PROC_START /
# SM_$DATA_START / SM_$DATA_END (sm/sm.ins.pas), SM_C_$PROC_START (sm_c),
# MT_$PROC_START (mt/mt.ins.pas), LPR_$PROC_START / LPR_$DATA_START /
# LPR_$DATA_END (lpr/lpr.ins.pas), IIC_$PROC_START / IIC_$DATA_END
# (iic/iic.ins.pas, with the map's IIC_$PROC_END and IIC_$DATA_START
# between them).  The SAU3 has no PEB wired data: PEB_$WIRED_DATA_START =
# PEB_$WIRED_DATA_END = LPR_$DATA_START, LPR_'s .DATA block.
# LPR_$DATA_END is the byte before the block after CBUF's (MARK_DELTAS).
TEXT_MARKS[3] = [
    (0x00E1CC00, 'OS_DATA_WIRED', PAGE),      # D24 E1CC00 WIRED_DATA
    (0x00E2CCF4, 'DCTE_START', None),         # D48 E2CCF4 DCTE_START
    (0x00E2CCF4, 'DCTE_END', None),           # D47 E2CCF4 DCTE_END
    (0x00E2DC00, 'OS_INIT_START', PAGE),      # I 5 E2DC00 OS_INIT_PROC
    (0x00E3377C, 'OS_INIT_END', None),        # E3377C OS_INIT_END
    (0x00E38000, 'OS_PROC_UNWIRED', 0x8000),  # I 1 E38000 .TEXT
    (0x00E3DE7A, 'OS_DISK_PROC_END', None),   # I E3DE78 OS_DISK_END
    (0x00E6DB00, 'SM_$PROC_START', None),     # I E6DB00 SM
    (0x00E6E622, 'OS_PROC_SHUTWIRED_END', None),  # I E6E620 OS_SHUTWIRED_END
    (0x00E6E6C0, 'PEB_$WIRED_PROC_START', None),  # I E6E6C0 PEB_WIRED
    (0x00E6E722, 'PEB_$WIRED_PROC_END', None),    # I E6E720 PEB_WIRED_END
    (0x00E6E724, 'LPR_$PROC_START', None),        # I E6E724 LPR_
    (0x00E6EDD0, 'SM_C_$PROC_START', None),       # I E6EDD0 SM_C
    (0x00E70FD8, 'MT_$PROC_START', None),         # I E70FD8 MT_$SIO
    (0x00E721D0, 'AUDIT_$PROC_START', None),      # I E721D0 AUDIT
    (0x00E72FE6, 'AUDIT_$PROC_END', None),        # I E72FE4 AUDIT (size 4)
    (0x00E72FE8, 'NETLOG_$PROC_START', None),     # I E72FE8 NETLOG
    (0x00E7344E, 'NETLOG_$PROC_END', None),       # I E7344C NETLOG (size 4)
    (0x00E76C00, 'RING_PROC_START', PAGE),    # I 8 E76C00 RING_PROC / D62
                                              # RING_PROC_START
    (0x00E79724, 'RING_PROC_END', None),      # D61 E79724 RING_PROC_END
    (0x00E79C00, 'OS_DATA_UNWIRED', PAGE),    # D21 E79C00 .DATA (= OS_DATA)
    (0x00E79CD0, 'OS_DISK_DATA', None),       # D E79CD0 VTOC_
    (0x00E7C708, 'OS_DISK_DATA_END', None),   # D E7C708 SVC_CATCHER
    (0x00E8383C, 'OS_DATA_SHUTWIRED', None),      # D E8383C FILE_
    (0x00E83CD4, 'SM_$DATA_START', None),         # D E83CD4 SM
    (0x00E83D30, 'OS_DATA_SHUTWIRED_END', None),  # D E83D30 DTTY_ASM
    (0x00E83D30, 'SM_$DATA_END', None),           # D E83D30 DTTY_ASM
    (0x00E8417C, 'PEB_$WIRED_DATA_START', None),  # D E8417C LPR_
    (0x00E8417C, 'PEB_$WIRED_DATA_END', None),    # D E8417C LPR_
    (0x00E8417C, 'LPR_$DATA_START', None),        # D E8417C LPR_
    (0x00E844D8, 'LPR_$DATA_END', None),          # E844D7 (D E844D4 CBUF
                                                  # size = 4, then D E844D8
                                                  # IIC): MARK_DELTAS
    (0x00E84584, 'AUDIT_$DATA_START', None),      # D E84584 AUDIT
    (0x00E84730, 'AUDIT_$DATA_END', None),        # D E84730 NETLOG
    (0x00E84730, 'NETLOG_$DATA_START', None),     # D E84730 NETLOG
    (0x00E847B4, 'NETLOG_$DATA_END', None),       # D E847B4 DXM_WIRED_
    (0x00E85400, 'IIC_$PROC_START', PAGE),    # I18 E85400 IIC_AQWRD_PROC
    (0x00E86210, 'IIC_$PROC_END', None),      # D40 E86210 IIC_AQWRD_DATA2
    (0x00E865C8, 'IIC_$DATA_START', None),    # D39 E865C8 IIC_AQWRD_DATA
    (0x00E865D0, 'IIC_$DATA_END', None),      # E865D0 IIC_$DATA_END
    (0x00E86800, 'RING_DATA_START', PAGE),    # D30 E86800 RING_DATA / D60
                                              # RING_DATA_START
    (0x00E86DD0, 'RING_DATA_END', None),      # D59 E86DD0 RING_DATA_END
    (0x00E87400, 'RTWIRED_PROC_START', PAGE),  # I12 E87400 RTWIRED_CODE
    (0x00E88628, 'RTWIRED_DATA_END', None),   # E88628 RTWIRED_DATA_END
    (0x00E89BA4, 'PBU_$PAGE_END', None),      # E89BA4 PBU_$PAGE_END (I16
                                              # E89BA4 PBU_WIRED_PROC)
    (0x00E8A360, 'PBU_$DATA_END', None),      # E8A360 PBU_$DATA_END
]
# Marks the map puts off the item boundary they are emitted at: `NAME = .
# + delta;'.  The SAU3's LPR_$DATA_END (E844D7) is the last byte of CBUF's
# 4-byte block (`D E844D4 CBUF'), the byte before IIC's block (the SAU2's,
# E854D7, the byte before AUDIT's block).
MARK_DELTAS = {3: {'LPR_$DATA_END': -1}}
# The SAU9's: the same marks at its map's addresses (most of them map
# symbols there), the page-aligned starts of the drivers' sections its
# Pascal names for MST_$WIRE_AREA (ETHER_PROC_START, ETHER_DATA_START,
# RING8025_PROC_ST, RING8025_DATA_ST: the map's 4-byte segments around
# the drivers' code and data, which the marks stand for; the ends at the
# end segments' addresses).
TEXT_MARKS[9] = [
    (0x3C420800, 'OS_DATA_WIRED', PAGE),      # D25 3C420800 WIRED_DATA
    # the dynamic DCTE area: MONO9_DESC (0x40 bytes) on the SAU9
    (0x3C433600, 'DCTE_START', None),         # D51 3C433600 DCTE_START
    (0x3C433640, 'DCTE_END', None),           # D50 3C433640 DCTE_END
    (0x3C434C00, 'OS_INIT_START', PAGE),      # I 6 3C434C00 OS_INIT_PROC
    (0x3C43BC00, 'OS_INIT_DATA_START', PAGE),  # D26 3C43BC00 OS_INIT_DATA
    (0x3C43CFA0, 'OS_INIT_END', None),        # 3C43CFA0 OS_INIT_END
    (0x3C440000, 'OS_PROC_UNWIRED', 0x8000),  # I 1 3C440000 .TEXT
    (0x3C445C2E, 'OS_DISK_PROC_END', None),   # I 3C445C2C OS_DISK_END
    (0x3C474344, 'SM_$PROC_START', None),     # I 3C474344 SM_END_ADDR
    (0x3C47434A, 'OS_PROC_SHUTWIRED_END', None),  # I 3C474348 OS_SHUTWIRED_END
    (0x3C4770E0, 'PEB_$WIRED_PROC_START', None),  # I 3C4770E0 PEB_WIRED
    (0x3C477142, 'PEB_$WIRED_PROC_END', None),    # I 3C477140 PEB_WIRED_END
    (0x3C47714C, 'SM_C_$PROC_START', None),       # I 3C47714C SM_C_END_ADDR
    (0x3C477154, 'MT_$PROC_START', None),         # I 3C477154 MT_END_ADDR
    (0x3C4771F8, 'CT_$PROC_START', None),         # I 3C4771F8 CT
    (0x3C478508, 'AUDIT_$PROC_START', None),      # I 3C478508 AUDIT
    (0x3C47930A, 'AUDIT_$PROC_END', None),        # I 3C479308 AUDIT (size 4)
    (0x3C47930C, 'NETLOG_$PROC_START', None),     # I 3C47930C NETLOG
    (0x3C47975E, 'NETLOG_$PROC_END', None),       # I 3C47975C NETLOG (size 4)
    (0x3C47D000, 'RING_PROC_START', PAGE),    # I 9 3C47D000 RING_PROC / D63
                                              # RING_PROC_START
    (0x3C4803F0, 'RING_PROC_END', None),      # D62 3C4803F0 RING_PROC_END
    (0x3C480400, 'ETHER_PROC_START', PAGE),   # D57 3C480400 ETHER_PROC_START
    (0x3C484B08, 'ETHER_PROC_END', None),     # D56 3C484B08 ETHER_PROC_END
    (0x3C484C00, 'RING8025_PROC_ST', PAGE),   # D68 3C484C00 RING8025_PROC_ST
    (0x3C489418, 'RING8025_PROC_EN', None),   # D67 3C489418 RING8025_PROC_EN
    (0x3C489800, 'OS_DATA_UNWIRED', PAGE),    # D22 3C489800 .DATA (= OS_DATA)
    (0x3C4898D0, 'OS_DISK_DATA', None),       # D 3C4898D0 VTOC_
    (0x3C48C308, 'OS_DISK_DATA_END', None),   # D 3C48C308 SVC_CATCHER
    (0x3C49A8AC, 'OS_DATA_SHUTWIRED', None),      # D 3C49A8AC FILE_
    (0x3C49AEC4, 'OS_DATA_SHUTWIRED_END', None),  # D 3C49AEC4 DTTY_ASM
    (0x3C49AEC4, 'SM_$DATA_START', None),         # 3C49AEC4 SM_$DATA_START
    (0x3C49AEC4, 'SM_$DATA_END', None),           # 3C49AEC4 SM_$DATA_END
    # no PEB wired data on the SAU9: start = end = CT's data
    (0x3C49D0BC, 'PEB_$WIRED_DATA_START', None),  # 3C49D0BC
    (0x3C49D0BC, 'PEB_$WIRED_DATA_END', None),    # 3C49D0BC
    (0x3C49D0BC, 'CT_$DATA_START', None),         # D 3C49D0BC CT
    (0x3C49DE48, 'CT_$DATA_END', None),           # D 3C49DE48 AUDIT
    (0x3C49DE48, 'AUDIT_$DATA_START', None),      # D 3C49DE48 AUDIT
    (0x3C49DFF4, 'AUDIT_$DATA_END', None),        # D 3C49DFF4 NETLOG
    (0x3C49DFF4, 'NETLOG_$DATA_START', None),     # D 3C49DFF4 NETLOG
    (0x3C49E078, 'NETLOG_$DATA_END', None),       # 3C49E078 (DATA$)
    (0x3C49EC00, 'RING_DATA_START', PAGE),    # D34 3C49EC00 RING_DATA / D61
                                              # RING_DATA_START
    (0x3C49F748, 'RING_DATA_END', None),      # D60 3C49F748 RING_DATA_END
    (0x3C49F800, 'ETHER_DATA_START', PAGE),   # D55 3C49F800 ETHER_DATA_START
    (0x3C49F8E4, 'ETHER_DATA_END', None),     # D54 3C49F8E4 ETHER_DATA_END
    (0x3C4A2400, 'RING8025_DATA_ST', PAGE),   # D66 3C4A2400 RING8025_DATA_ST
    (0x3C4A256C, 'RING8025_DATA_EN', None),   # D65 3C4A256C RING8025_DATA_EN
    (0x3C4A3400, 'RTWIRED_PROC_START', PAGE),  # I13 3C4A3400 RTWIRED_CODE
    (0x3C4A45FC, 'RTWIRED_DATA_END', None),   # 3C4A45FC RTWIRED_DATA_END
    (0x3C4A4B60, 'PBU_$DATA_END', None),      # 3C4A4B60 PBU_$DATA_END
    # the SCSI driver's wired range (scsi/wire_driver.pas): the start of
    # `I18 3C4A4C00 SCSI_WIRED_PROC' and the end of `D43 3C4A7240
    # SCSI_WIRED_DATA size = 374' (no map names)
    (0x3C4A4C00, 'SCSI_$PROC_START', PAGE),
    (0x3C4A75B4, 'SCSI_$DATA_END', None),
]
# The SAU8's: the SAU9's marks at its map's addresses (map symbols there
# but for OS_PROC_UNWIRED, OS_DATA_WIRED, OS_DATA_UNWIRED and the drivers'
# section starts and ends, the map's numbered sections and 4-byte
# segments, as on the SAU9).  The SAU8 has no PEB wired data and no SM_ or
# MT_ data (their start and end at CT's data); its dynamic DCTE area is
# empty; the SCSI driver's range is the map's two 4-byte stubs.
TEXT_MARKS[8] = [
    (0x03C1F400, 'OS_DATA_WIRED', PAGE),      # D25 3C1F400 WIRED_DATA
    (0x03C30564, 'DCTE_START', None),         # D54 3C30564 DCTE_START
    (0x03C30564, 'DCTE_END', None),           # D53 3C30564 DCTE_END
    (0x03C31C00, 'OS_INIT_START', PAGE),      # I 5 3C31C00 OS_INIT_PROC
    (0x03C39400, 'OS_INIT_DATA_START', PAGE),  # D26 3C39400 OS_INIT_DATA
    (0x03C399B8, 'OS_INIT_END', None),        # 3C399B8 OS_INIT_END
    (0x03C40000, 'OS_PROC_UNWIRED', 0x8000),  # I 1 3C40000 .TEXT
    (0x03C468FA, 'OS_DISK_PROC_END', None),   # I 3C468F8 OS_DISK_END
    (0x03C76AE8, 'SM_$PROC_START', None),     # I 3C76AE8 SM_END_ADDR
    (0x03C76AEE, 'OS_PROC_SHUTWIRED_END', None),  # I 3C76AEC OS_SHUTWIRED_END
    (0x03C79F50, 'PEB_$WIRED_PROC_START', None),  # I 3C79F50 PEB_WIRED
    (0x03C79FB2, 'PEB_$WIRED_PROC_END', None),    # I 3C79FB0 PEB_WIRED_END
    (0x03C79FBC, 'SM_C_$PROC_START', None),       # I 3C79FBC SM_C_END_ADDR
    (0x03C79FC4, 'MT_$PROC_START', None),         # I 3C79FC4 MT_END_ADDR
    (0x03C7A068, 'CT_$PROC_START', None),         # I 3C7A068 CT
    (0x03C7B3D8, 'AUDIT_$PROC_START', None),      # I 3C7B3D8 AUDIT
    (0x03C7C1DA, 'AUDIT_$PROC_END', None),        # I 3C7C1D8 AUDIT (size 4)
    (0x03C7C1DC, 'NETLOG_$PROC_START', None),     # I 3C7C1DC NETLOG
    (0x03C7C62E, 'NETLOG_$PROC_END', None),       # I 3C7C62C NETLOG (size 4)
    # COLOR5's wired code's end (color5/color5.pas COLOR5_$WIRED_DATA
    # names it): the map's symbol at `D81 3C80C38 COLOR6_WIRED_PRO'
    (0x03C80C38, 'COLOR5_$END_WIRED_PROC', None),
    (0x03C81400, 'RING_PROC_START', PAGE),    # I 8 3C81400 RING_PROC / D67
                                              # RING_PROC_START
    (0x03C847FC, 'RING_PROC_END', None),      # D66 3C847FC RING_PROC_END
    (0x03C84800, 'ETHER_PROC_START', PAGE),   # D61 3C84800 ETHER_PROC_START
    (0x03C88EE0, 'ETHER_PROC_END', None),     # D60 3C88EE0 ETHER_PROC_END
    (0x03C89000, 'RING8025_PROC_ST', PAGE),   # D72 3C89000 RING8025_PROC_ST
    (0x03C8D758, 'RING8025_PROC_EN', None),   # D71 3C8D758 RING8025_PROC_EN
    (0x03C8D800, 'OS_DATA_UNWIRED', PAGE),    # D22 3C8D800 .DATA (= OS_DATA)
    (0x03C8D8D0, 'OS_DISK_DATA', None),       # D 3C8D8D0 VTOC_
    (0x03C90504, 'OS_DISK_DATA_END', None),   # D 3C90504 SVC_CATCHER
    (0x03C9AC18, 'OS_DATA_SHUTWIRED', None),      # D 3C9AC18 FILE_
    (0x03C9B230, 'OS_DATA_SHUTWIRED_END', None),  # D 3C9B230 DTTY_ASM
    (0x03C9B230, 'SM_$DATA_START', None),         # 3C9B230 SM_$DATA_START
    (0x03C9B230, 'SM_$DATA_END', None),           # 3C9B230 SM_$DATA_END
    # no PEB wired data on the SAU8: start = end = CT's data
    (0x03C9D43C, 'PEB_$WIRED_DATA_START', None),  # 3C9D43C
    (0x03C9D43C, 'PEB_$WIRED_DATA_END', None),    # 3C9D43C
    (0x03C9D43C, 'CT_$DATA_START', None),         # D 3C9D43C CT
    (0x03C9E180, 'CT_$DATA_END', None),           # D 3C9E180 AUDIT
    (0x03C9E180, 'AUDIT_$DATA_START', None),      # D 3C9E180 AUDIT
    (0x03C9E32C, 'AUDIT_$DATA_END', None),        # D 3C9E32C NETLOG
    (0x03C9E32C, 'NETLOG_$DATA_START', None),     # D 3C9E32C NETLOG
    (0x03C9E3B0, 'NETLOG_$DATA_END', None),       # 3C9E3B0 (DATA$)
    (0x03C9F000, 'RING_DATA_START', PAGE),    # D33 3C9F000 RING_DATA / D65
                                              # RING_DATA_START
    (0x03C9FB48, 'RING_DATA_END', None),      # D64 3C9FB48 RING_DATA_END
    (0x03C9FC00, 'ETHER_DATA_START', PAGE),   # D59 3C9FC00 ETHER_DATA_START
    (0x03C9FCE4, 'ETHER_DATA_END', None),     # D58 3C9FCE4 ETHER_DATA_END
    (0x03CA2800, 'RING8025_DATA_ST', PAGE),   # D70 3CA2800 RING8025_DATA_ST
    (0x03CA2968, 'RING8025_DATA_EN', None),   # D69 3CA2968 RING8025_DATA_EN
    (0x03CA3800, 'RTWIRED_PROC_START', PAGE),  # I12 3CA3800 RTWIRED_CODE
    (0x03CA49FC, 'RTWIRED_DATA_END', None),   # 3CA49FC RTWIRED_DATA_END
    (0x03CA5FC4, 'PBU_$DATA_END', None),      # 3CA5FC4 PBU_$DATA_END
    (0x03CA6000, 'SCSI_$PROC_START', PAGE),   # I18 3CA6000 SCSI_WIRED_PROC
    (0x03CA6008, 'SCSI_$DATA_END', None),     # 3CA6008 (D46 SCSI_WIRED_DATA
                                              # size = 4)
]
BSS_MARKS = {}
BSS_MARKS[2] = [
    (0x00EA9684, 'OS_DATA_END', None),        # D91 EA9684 OS_DATA_END
    (0x00EB0000, 'OS_PAGE', 0x8000),          # D64 EB0000 PAGE / D90 OS_PAGE
]
BSS_MARKS[3] = [
    (0x00EAB284, 'OS_DATA_END', None),        # D92 EAB284 OS_DATA_END
    (0x00EB0000, 'OS_PAGE', 0x8000),          # D68 EB0000 PAGE / D91 OS_PAGE
]
BSS_MARKS[5] = [
    (0x00EB3684, 'OS_DATA_END', None),        # D91 EB3684 OS_DATA_END
    (0x00EB8000, 'OS_PAGE', 0x8000),          # D67 EB8000 PAGE / D90 OS_PAGE
]
BSS_MARKS[8] = [
    (0x03CC7448, 'OS_DATA_END', None),        # D96 3CC7448 OS_DATA_END
    (0x03CC8000, 'OS_PAGE', 0x8000),          # D73 3CC8000 PAGE / D94 OS_PAGE
]
BSS_MARKS[9] = [
    (0x3C4C8428, 'OS_DATA_END', None),        # D94 3C4C8428 OS_DATA_END
    (0x3C4D0000, 'OS_PAGE', 0x8000),          # D69 3C4D0000 PAGE / D92 OS_PAGE
]
# Not a map symbol: the start of the catch-all at the end of `.text' (and
# kernel.ld's .rodata and .data after it), up to RELOC.  Every input
# section is placed by map position, anchor or owner, so the range is
# empty; OS_$INIT does not keep it wired.
UNPLACED_MARK = 'OS_LINK_UNPLACED'


# The binder's page alignment of the numbered sections.  A numbered section
# of the map that starts a page was put there by the binder: on each SAU's
# map every one of them in the kernel follows either a gap up to the page,
#   D35  E2E3FC  SMD_$WIRED_DATA    loaded at 12FBFC, size = 13C
#   D27  E2E800  PAGE_INIT          loaded at 130000, size = 480
# (SMD_$WIRED_DATA ends at E2E538), or a section that ends on the page
# (the SAU3's `D38 E88800 MT_PAGE size = C00', then `D35 E89400 PBU_PAGE'),
# and no numbered section that starts mid-page follows a gap: each starts
# where the one before it ends.  So a page starts (`. = ALIGN(0x400)') just
# before the first item placed at or past each such section's map address,
# past OS_PROC (kernel.ld starts `.text' on a page) and below the VM tables'
# run-time windows (layout_vm.ld lays them out at their map offsets from
# OS_PAGE_END, a page).  Where a mark at the same address aligns to a page
# or more (OS_INIT_START, RING_PROC_START, OS_PAGE, ...) that is the
# alignment.  The wired-on-demand ranges rely on it: MT_$ACQUIRE and
# PBU_$WIRE_PBU wire the pages from MT_$PAGE_START and PBU_$PAGE_START,
# the first bytes of MT_PAGE and PBU_PAGE.
def page_sections(linkmap):
    """[(addr, [(`D27', name), ...])] of the map's numbered sections
    that start a page, past OS_PROC and below the VM tables' run-time
    windows, in address order."""
    os_proc = [a for a, _, name, _ in linkmap.numbered if name == 'OS_PROC']
    if len(os_proc) != 1:
        fail(['the map has %d numbered OS_PROC section(s), not one'
              % len(os_proc)])
    found = {}
    for addr, _, name, label in linkmap.numbered:
        if addr % PAGE == 0 and os_proc[0] < addr < VM_WINDOWS_START[SAU]:
            found.setdefault(addr, []).append((label, name))
    return sorted(found.items())


def section_aligns(linkmap, marks, lo, hi):
    """`marks' with the page alignments of the page_sections in [lo, hi)
    merged in as entries (addr, None, PAGE, sections): ahead of the marks
    at the same address, and none where a mark there aligns to a page or
    more."""
    have = {a for a, _, align in marks if align and align >= PAGE}
    merged = list(marks)
    for addr, secs in page_sections(linkmap):
        if lo <= addr < hi and addr not in have:
            merged.append((addr, None, PAGE, secs))
    merged.sort(key=lambda m: (m[0], m[1] is not None))
    return merged


def section_names(secs):
    return ' / '.join('%s %s' % (label, name) for label, name in secs)


def emit_marks(out, marks, upto, item_align=1):
    """Emit (and drop from `marks') every mark whose map address is at or
    below `upto' (None: all of them).  `item_align' is the alignment of the
    item that follows: ld aligns it anyway, so aligning first puts a mark
    on the item's first byte, not before the padding (a start mark such as
    PEB_$WIRED_DATA_START names that byte; an end mark only takes the
    padding in).  A section_aligns entry is its page alignment, unless an
    alignment just emitted or the next mark's own gives one (at the end of
    the stream, with no item to align, it is dropped).  Returns the
    alignment the emitted statements leave `.' at (1: none)."""
    cur = 1
    while marks and (upto is None or marks[0][0] <= upto):
        addr, name, align = marks[0][:3]
        if name is None:
            secs = marks.pop(0)[3]
            if upto is None:
                continue
            # the next mark that pops, if it aligns as far itself
            nxt = next((m for m in marks if m[1] is not None), None)
            if nxt and nxt[0] <= upto and nxt[2] and nxt[2] >= align:
                continue
            if cur < align:
                stmt = '. = ALIGN(0x%X);' % align
                out.append('    %s%s/* %06X map %s starts a page */'
                           % (stmt, pad(stmt, 0), addr, section_names(secs)))
                cur = align
            continue
        marks.pop(0)
        if cur < item_align:
            out.append('    . = ALIGN(%d);' % item_align)
            cur = item_align
        if align:
            out.append('    . = ALIGN(0x%X);' % align)
            cur = max(cur, align)
        # ld needs a name with `$' quoted
        delta = MARK_DELTAS.get(SAU, {}).get(name, 0)
        if delta:
            stmt = '%s = . - %d;' % (ld_name(name), -delta)
        else:
            stmt = '%s = .;' % ld_name(name)
        out.append('    %s%s/* %06X map %s */' % (stmt, pad(stmt, 0),
                                                  addr + delta, name))
    return cur

# Sections holding image data whose C names are not the map's.  Keyed by the
# image address of their first byte.
ANCHORS = {}
ANCHORS[2] = {
    # svc/m68k/svc_tables.s: the nine SVC dispatch tables, which in the
    # image follow the eight trap dispatchers inside SVC_CATCHER (0xE7B044,
    # size 0xE40), 0xE7B2DE..0xE7BE84, reached with `lea (TABLE:w,%pc)' -
    # R_68K_PC16.  The map names only the dispatchers.
    '.text.svc_tables': 0xE7B2DE,
    # fp/m68k/fp_context.s: fp_$switch_owner .. fp_$save_state
    # (0xE21B10..0xE21B7F), which the map counts into FIM_$FLINE (it names
    # no symbol between FIM_$FLINE 0xE21ACC and FIM_$FP_ABORT 0xE21B80);
    # FIM_$FLINE reaches it with `bsr.s'.
    '.text.fp_$switch_owner': 0xE21B10,
    # time/m68k/timer_handler.s: TIME_$TIMER_HANDLER (0xE2B130..0xE2B27F),
    # the end of the TIME_ASM segment; the map names no symbol after
    # TIME_$DI_RTE (0xE2B11E), and TIME_$SET_VECTOR reaches the handler with
    # `lea (0x2c,PC)'.
    '.text.TIME_$TIMER_HANDLER': 0xE2B130,
    # fim/m68k/com.s: FIM_COMMON_FAULT, the `pea (4,SP)' that the vector
    # stubs `bsr' to and that falls into FIM_$COM (0xE213A4); it is the
    # first word of the FIM_UNWIRED segment (0xE213A0), where the map names
    # no symbol.
    '.text.FIM_UNWIRED': 0xE213A0,
    # os/m68k/nullproc.s: NULLPROC, the null process's idle loop, is the
    # map's wired `D E24C60 NULLPROC size 18' (symbol NULL_LOOP, module-
    # local); OS_$INIT takes its address for PROC1_$CREATE_P, so without
    # an anchor it would be placed as an escaping routine.
    '.text.NULLPROC': 0xE24C60,
    # io/m68k/probe.s: the map's TESTPAGE (`D E29138 TESTPAGE size 60').
    '.text.io_$probe': 0xE29138,
}
# The same sections at the SAU3's addresses (tools/asm_compare.py's SAU3
# LOCAL_SYMBOLS give the first symbol of each).
ANCHORS[3] = {
    # SVC_$TRAP0_TABLE, inside `D E7C708 SVC_CATCHER size = E40'
    '.text.svc_tables': 0xE7C9A2,
    # fp_$switch_owner, inside FIM_$FLINE's span (FIM_$FLINE 0xE20A1C,
    # FIM_$FP_ABORT 0xE20AD0)
    '.text.fp_$switch_owner': 0xE20A60,
    # TIME_$TIMER_HANDLER, the end of TIME_ASM after TIME_$DI_RTE + 0x10
    '.text.TIME_$TIMER_HANDLER': 0xE29A8C,
    # `D E202D8 FIM_UNWIRED size = 4F0'
    '.text.FIM_UNWIRED': 0xE202D8,
    # `D E23BAC NULLPROC size = 18' (NULL_LOOP)
    '.text.NULLPROC': 0xE23BAC,
    # `D E27AA4 TESTPAGE size = 60'
    '.text.io_$probe': 0xE27AA4,
}
# The same sections at the SAU5's addresses (tools/asm_compare.py's SAU5
# LOCAL_SYMBOLS give the first symbol of each), and smd/sau5/
# wired_proc.s's two sections with no map symbol.
ANCHORS[5] = {
    # SVC_$TRAP0_TABLE, inside `D E82308 SVC_CATCHER size = E40'
    '.text.svc_tables': 0xE825A2,
    # fp_$switch_owner, inside FIM_$FLINE's span (FIM_$FLINE 0xE227E8,
    # FIM_$FP_ABORT 0xE2289C)
    '.text.fp_$switch_owner': 0xE2282C,
    # TIME_$TIMER_HANDLER, the end of TIME_ASM after TIME_$DI_RTE
    '.text.TIME_$TIMER_HANDLER': 0xE2C26C,
    # `D E22068 FIM_UNWIRED size = 4F0'
    '.text.FIM_UNWIRED': 0xE22068,
    # `D E25AB8 NULLPROC size = 18' (NULL_LOOP)
    '.text.NULLPROC': 0xE25AB8,
    # `D E2A260 TESTPAGE size = 74'
    '.text.io_$probe': 0xE2A260,
    # smd/sau5/wired_proc.s: the start of `I E15D3C SMD_WIRED size = 69C'
    # up to SMD_$LOCK_DISPLAY, and the body after SMD_$BIT_SET from
    # 0xE16370 to the segment's end 0xE163D8; neither defines a map symbol
    # (the bodies are globals of ours).
    '.text.SMD_WIRED': 0xE15D3C,
    '.text.smd_$start_blt_body': 0xE16370,
}

# A segment line: the kind (D or I), a two-column section number (blank
# on a module's segment) and the address right-aligned in eight columns,
# which an eight-digit address fills (the SAU9's `D993C000000 UNWIRED_
# STACKS': section 99 at 0x3C000000).
# The SAU9's (tools/asm_compare.py's SAU9 LOCAL_SYMBOLS give the first
# symbol of each); its TIME_$TIMER_HANDLER is inside time/sau9/time_asm.s's
# section, and fim/sau9/nmi.s's fault path after FIM_$SPUR_CNT has none.
# The SAU8's (tools/asm_compare.py's SAU8 LOCAL_SYMBOLS give the first
# symbol of each).
ANCHORS[8] = {
    # SVC_$TRAP0_TABLE, inside `D 3C90504 SVC_CATCHER size = E40'
    '.text.svc_tables': 0x03C9079E,
    # fp_$switch_owner, inside FIM_$FLINE's span (FIM_$FLINE 0x3C2334C,
    # FIM_$FP_ABORT 0x3C23428)
    '.text.fp_$switch_owner': 0x03C233A0,
    # TIME_$TIMER_HANDLER, the end of TIME_ASM after TIME_$DI_RTE + 0x12
    '.text.TIME_$TIMER_HANDLER': 0x03C2D090,
    # `D 3C22BE0 FIM_UNWIRED size = 4F0'
    '.text.FIM_UNWIRED': 0x03C22BE0,
    # `D 3C26D08 NULLPROC size = 18' (NULL_LOOP)
    '.text.NULLPROC': 0x03C26D08,
    # `D 3C2B0D8 TESTPAGE size = 70'
    '.text.io_$probe': 0x03C2B0D8,
}
ANCHORS[9] = {
    # SVC_$TRAP0_TABLE, inside `D 3C48C308 SVC_CATCHER size = E40'
    '.text.svc_tables': 0x3C48C5A2,
    # fp_$switch_owner, inside FIM_$FLINE's span (FIM_$FLINE 0x3C42471C,
    # FIM_$FP_ABORT 0x3C4247EC)
    '.text.fp_$switch_owner': 0x3C42477A,
    # `D 3C423FB0 FIM_UNWIRED size = 4F0'
    '.text.FIM_UNWIRED': 0x3C423FB0,
    # `D 3C428460 NULLPROC size = 18' (NULL_LOOP)
    '.text.NULLPROC': 0x3C428460,
    # `D 3C42C830 TESTPAGE size = 74'
    '.text.io_$probe': 0x3C42C830,
    # FIM_$NMI's fault path, FIM_$SPUR_CNT + 6 (before PARITY_$INFO)
    '.text.fim_$nmi_fault': 0x3C424BF0,
}

SEGMENT_RE = re.compile(
    r'^[DI][ 0-9]{2}\s*(?P<addr>[0-9A-F]+)\s+(?P<name>\S+)\s+.*'
    r'size = (?P<size>[0-9A-F]+)')

SYMTAB_RE = re.compile(
    r'^(?P<value>[0-9a-f]{8}) (?P<flags>.{7}) (?P<sec>\S+)\s+'
    r'(?P<size>[0-9a-f]{8}) (?P<name>.+)$')


def fail(msgs):
    for m in msgs:
        print('gen_layout_ld: error: ' + m, file=sys.stderr)
    sys.exit(1)


def warn(msg):
    print('gen_layout_ld: warning: ' + msg, file=sys.stderr)


# ---------------------------------------------------------------------------
# The link map
# ---------------------------------------------------------------------------

class LinkMap:
    def __init__(self, path):
        self.symbols = {}   # name -> (addr, line): first occurrence
        self.segments = []  # (addr, size, name)
        self.records = []   # (addr, size, name, 'D' or 'I')
        # one module's contribution to a section (`D E2C008 UID_ size = C',
        # no section number): (kind, addr, size, module, section), the
        # section being the last numbered line of that kind, of nonzero
        # size, that holds it (`D24 E1DC00 WIRED_DATA ...').  The map
        # truncates names to 16 characters (PROC2_CREATE_DAT).
        self.module_segments = []
        # the numbered sections, any size: (addr, size, name, `D27' / `I 5')
        self.numbered = []
        current = {}        # 'D'/'I' -> (addr, size, name) of the section
        with open(path, encoding='latin-1') as f:
            for line_no, line in enumerate(f):
                if line_no == 0:
                    continue  # build banner
                if line.startswith(' '):
                    fields = line.split()
                    if (len(fields) >= 2
                            and re.fullmatch(r'[0-9A-F]+', fields[0])):
                        self.symbols.setdefault(
                            fields[1], (int(fields[0], 16), line_no))
                    continue
                m = SEGMENT_RE.match(line)
                if not m:
                    continue
                addr, size = int(m.group('addr'), 16), int(m.group('size'), 16)
                kind, numbered = line[0], line[1:3].strip() != ''
                if numbered:
                    self.numbered.append((addr, size, m.group('name'),
                                          line[:3]))
                    if size:
                        current[kind] = (addr, size, m.group('name'))
                elif size:
                    sec = current.get(kind)
                    if sec and sec[0] <= addr < sec[0] + sec[1]:
                        self.module_segments.append(
                            (kind, addr, size, m.group('name'), sec[2]))
                if size:
                    self.segments.append((addr, size, m.group('name')))
                    self.records.append(self.segments[-1] + (kind,))

    def module_segment(self, kind, module, section):
        """The address of MODULE's segment of KIND ('D' or 'I') in the map
        section SECTION (compared on the map's 16 characters, any case), or
        None; and the candidates, for a message."""
        cands = [s for s in self.module_segments
                 if s[0] == kind and s[3].upper() == module.upper()]
        want = section.upper()[:16]
        hits = [s for s in cands if s[4].upper()[:16] == want]
        return (hits[0][1] if len(hits) == 1 else None), cands

    def key(self, name):
        """Ordering key of a map symbol: (address, 1 + map line)."""
        addr, line = self.symbols[name]
        return (addr, 1 + line)

    def segment_of(self, addr):
        """The innermost map segment holding addr (the map nests object
        segments inside the numbered load regions)."""
        inside = [(size, name) for start, size, name in self.segments
                  if start <= addr < start + size]
        return min(inside)[1] if inside else None

    def nearest_segment(self, addr):
        def dist(seg):
            start, size, _ = seg
            return 0 if start <= addr < start + size else \
                min(abs(addr - start), abs(addr - (start + size - 1)))
        start, size, name = min(self.segments, key=dist)
        return '%s (0x%06X, size 0x%X)' % (name, start, size)


def addr_key(addr):
    """Ordering key of a declared address: ahead of every map symbol there."""
    return (addr, 0)


# ---------------------------------------------------------------------------
# Module data blocks (dpc's, keyed by the map: dpc_blocks)
# ---------------------------------------------------------------------------

class Block:
    def __init__(self, name, ctype, addr, src, line, init):
        self.name = name
        self.ctype = ctype
        self.addr = addr
        self.src = src
        self.line = line
        self.init = init    # `.moddata.': has file contents
        self.align = None   # its section's alignment (bytes)
        self.shared = False # its section name is in another object too

    @property
    def mark(self):
        """A dpc block defines no symbol of its name: the layout puts this
        one at its start, for --check-elf."""
        return '__dpc_block_%s_%06X' % (re.sub(r'[^A-Za-z0-9_]', '_', self.name),
                                        self.addr)

    @property
    def pattern(self):
        """The input-section statement: by object when the section name is
        shared by several units' objects."""
        return 'KEEP(%s("%s"))' % (self.src if self.shared else '*', self.section)

    @property
    def section(self):
        # arch/m68k/arch.h: a zero-filled block is NOBITS (`.bss.moddata.')
        return ('.moddata.' if self.init else '.bss.moddata.') + self.name

    @property
    def nobits(self):
        """Not in the file: a zero-filled block the image had as bss (its
        address is at or past the image's RELOC)."""
        return not self.init and \
            IMAGE_BSS_START[SAU] <= self.addr < IMAGE_BSS_END[SAU]

    @property
    def where(self):
        return '%s:%d' % (self.src, self.line)


# dpc's module data blocks (the Pascal build): `.moddata.<MODULE>[.<SECTION>]'
# with initial values, `.bss.moddata.<MODULE>[.<SECTION>]' zero-filled; no
# section name is the module's default data section, the map's `.DATA'.
DPC_BLOCK_RE = re.compile(
    r'^(?P<prefix>\.moddata\.|\.bss\.moddata\.)'
    r'(?P<module>[^.]+)(?:\.(?P<section>.+))?$')
# dpc's code sections: `.text.<MODULE>.<SECTION>', or plain `.text' for the
# module's default section (the map's `.TEXT').
DPC_TEXT_RE = re.compile(r'^\.text\.(?P<module>[^.]+)\.(?P<section>.+)$')


def dpc_blocks(linkmap, objdump, objects):
    """The Pascal build's module data blocks, from the objects' sections:
    each keyed by its module's data segment of the map (the address the C
    build's MODULE_DATA_DEFINE sites declared by hand).  -> (blocks,
    errors)"""
    blocks, errors = [], []
    found = []          # (object, section, size, alignment)
    for obj in objects:
        hdr = subprocess.run([objdump, '-h', obj], check=True,
                             capture_output=True, text=True).stdout
        for line in hdr.splitlines():
            f = line.split()
            if len(f) >= 7 and f[0].isdigit() and f[6].startswith('2**') \
                    and f[1].startswith(('.moddata.', '.bss.moddata.')):
                found.append((obj, f[1], int(f[2], 16), 1 << int(f[6][3:])))
    for obj, sec, size, align in sorted(found):
        if sec in SCRIPT_PLACED:
            continue    # kernel.ld's own (.cold)
        m = DPC_BLOCK_RE.match(sec)
        if not m:
            errors.append('%s: %s is no dpc module data section' % (obj, sec))
            continue
        msec = m.group('section') or '.DATA'
        addr, cands = linkmap.module_segment('D', m.group('module'), msec)
        if addr is None:
            # One map module of several compilation units has a data
            # segment per unit in the same section (DISK_: disk.pas,
            # disk_dev.pas and disk_vol.pas, three `.DATA' segments): the
            # unit's block is the one whose map size is the block's.
            want = msec.upper()[:16]
            same = [c for c in cands if c[4].upper()[:16] == want
                    and c[2] == size]
            if len(same) == 1:
                addr = same[0][1]
        if addr is None:
            errors.append('%s: %s: the map has no single data segment of '
                          'module %s in section %s (candidates: %s)'
                          % (obj, sec, m.group('module'), msec,
                             ', '.join('%s 0x%06X' % (c[4], c[1])
                                       for c in cands) or 'none'))
            continue
        init = m.group('prefix') == '.moddata.'
        b = Block(sec[len(m.group('prefix')):], 'pascal', addr, obj, 0, init)
        b.align = align
        blocks.append(b)
    # a section name in more than one object (one module, several units)
    # is placed per object
    count = {}
    for b in blocks:
        count[b.section] = count.get(b.section, 0) + 1
    for b in blocks:
        b.shared = count[b.section] > 1
    return blocks, errors


def block_checks(blocks, linkmap):
    errors = []
    seen = {}
    for b in blocks:
        if (b.name, b.addr) in seen:
            errors.append('%s: %s already defined at %s'
                          % (b.where, b.name, seen[(b.name, b.addr)].where))
        seen[(b.name, b.addr)] = b
        if b.addr & 1:
            errors.append('%s: %s at 0x%08X is not even-aligned'
                          % (b.where, b.name, b.addr))
        if b.addr < RFC_LOAD_ADDR[SAU] or b.addr >= KERNEL_VA_END[SAU]:
            errors.append('%s: %s at 0x%08X is outside the kernel range '
                          '0x%08X..0x%08X' % (b.where, b.name, b.addr,
                                              RFC_LOAD_ADDR[SAU], KERNEL_VA_END[SAU]))
        elif linkmap.segment_of(b.addr) is None:
            warn('%s: %s at 0x%08X is inside no map segment; nearest is %s'
                 % (b.where, b.name, b.addr,
                    linkmap.nearest_segment(b.addr)))
    return errors


def ld_name(name):
    """A symbol name as a linker-script statement writes it."""
    return ('"%s"' % name) if '$' in name else name


# ---------------------------------------------------------------------------
# Windows (BSS_WINDOWS) and overlay sections: map segments the layout
# defines by symbol
# ---------------------------------------------------------------------------

class Window:
    """A BSS_WINDOWS entry: a map segment no object fills, laid out by its
    map symbols at the map's offsets from the first."""

    def __init__(self, addr, module, size, syms):
        self.addr = addr        # the segment's map address
        self.name = module      # its module name in the map
        self.size = size        # bytes laid out here
        self.syms = syms        # [(map address, name)], map order

    @property
    def base(self):
        return self.syms[0][1]

    @property
    def where(self):
        return 'map D %06X %s' % (self.addr, self.name)


def bss_windows(linkmap):
    """The BSS_WINDOWS segments with their map symbols -> (windows, errors)"""
    windows, errors = [], []
    skip = BSS_WINDOW_SKIP | {name for _, name, _ in BSS_MARKS[SAU]}
    for addr, module, ends in BSS_WINDOWS[SAU]:
        segs = [s for s in linkmap.module_segments
                if s[0] == 'D' and s[1] == addr and s[3] == module]
        if len(segs) != 1:
            errors.append('BSS_WINDOWS: the map has no single `D %06X %s\' '
                          'segment' % (addr, module))
            continue
        end = min(addr + segs[0][2], VM_WINDOWS_START[SAU])
        if not IMAGE_BSS_START[SAU] <= addr < end:
            errors.append('BSS_WINDOWS: %06X %s is not in the image\'s bss '
                          'below VM_WINDOWS_START' % (addr, module))
            continue
        syms = sorted((a, line, n) for n, (a, line) in linkmap.symbols.items()
                      if n not in skip
                      and (addr <= a < end or (a == end and n in ends)))
        for n in ends:
            if linkmap.symbols.get(n, (None,))[0] != end:
                errors.append('BSS_WINDOWS: %s is not at the end 0x%06X of '
                              '`D %06X %s\'' % (n, end, addr, module))
        if not syms or syms[0][0] != addr:
            errors.append('BSS_WINDOWS: `D %06X %s\' has no map symbol at '
                          'its start to lay it out from' % (addr, module))
            continue
        windows.append(Window(addr, module, end - addr,
                              [(a, n) for a, _, n in syms]))
    return windows, errors


# dpc writes an overlay section (`var (name) ...', ref 3.14 p. 3-52, 7.2.4
# Method 4; gap 37) as a COMMON symbol of the section's name, the variables
# at offsets from it (`clr.l (SEC+4).l', `.comm SEC,12,4').  Every overlay
# section of the tree is a load section of the map (`D69 E88834 ACL_$DATA
# ... size = AD98', VTOC_CACHE, AUDIT_LIST, PCHIST_UNWIRED_D, ...), so the
# layout defines the symbol at that segment's map position and gives it
# the segment's size (the linker script's definition replaces the common:
# ld allocates no COMMON storage for a symbol the script defines).  In the
# image's bss it is NOBITS (layout_bss.ld); elsewhere zeros in the file
# among the code and data at its map position (layout.ld).
SHN_COMMON = 0xFFF2


class Overlay:
    def __init__(self, name, addr, size, align, objs, map_size):
        self.name = name
        self.addr = addr
        self.size = size        # bytes reserved: the map size if known
        self.align = align
        self.objs = objs
        self.map_size = map_size

    @property
    def nobits(self):
        return IMAGE_BSS_START[SAU] <= self.addr < IMAGE_BSS_END[SAU]

    @property
    def where(self):
        return 'COMMON %s (%s)' % (self.name, ', '.join(
            os.path.basename(o) for o in self.objs))


def overlay_sections(linkmap, objects):
    """The COMMON symbols of the inputs, each keyed by the map segment (or
    map symbol) of its name -> (overlays, errors)"""
    commons = {}
    for obj in objects:
        for name, value, size, _, shndx in rfc_elf.Elf(obj).symbols():
            if shndx == SHN_COMMON and name:
                c = commons.setdefault(name, [0, 1, []])
                c[0] = max(c[0], size)
                c[1] = max(c[1], value)
                c[2].append(obj)
    out, errors = [], []
    for name, (size, align, objs) in sorted(commons.items()):
        if name in LOW_OVERLAYS[SAU]:
            continue    # the SAU's script defines it (fixed VA)
        recs = {(a, sz) for a, sz, n, k in linkmap.records
                if k == 'D' and n.upper() == name.upper()[:16]}
        if len(recs) == 1:
            addr, map_size = recs.pop()
        elif not recs and name in linkmap.symbols:
            addr, map_size = linkmap.symbols[name][0], None
        else:
            errors.append('COMMON %s (%s): an overlay section needs one map '
                          'segment or symbol of its name (found %d)'
                          % (name, ', '.join(objs), len(recs)))
            continue
        if map_size is not None and size > map_size:
            errors.append('COMMON %s (%s) is 0x%X bytes, larger than the '
                          'map\'s segment (0x%X)'
                          % (name, ', '.join(objs), size, map_size))
            continue
        if addr >= IMAGE_BSS_END[SAU] or addr < RFC_LOAD_ADDR[SAU] or \
                (addr >= VM_WINDOWS_START[SAU] and not VM_OVERLAYS[SAU]):
            errors.append('COMMON %s: its map position 0x%06X is outside '
                          'the kernel\'s laid-out stream' % (name, addr))
            continue
        out.append(Overlay(name, addr, map_size or size, align, objs,
                           map_size))
    return out, errors


def layout_defined_names(linkmap):
    """The symbols the generated fragments define whatever the inputs
    (marks, VM-table windows, BSS_WINDOWS)."""
    names = {name for _, name, _ in TEXT_MARKS[SAU] + BSS_MARKS[SAU]}
    names |= set(VM_WINDOW_MARKS[SAU])
    names.add(UNPLACED_MARK)
    windows, _ = bss_windows(linkmap)
    for w in windows:
        names |= {n for _, n in w.syms}
    return names


# ---------------------------------------------------------------------------
# The link inputs
# ---------------------------------------------------------------------------

class Section:
    def __init__(self, obj, name, size, kind):
        self.obj = obj
        self.name = name
        self.size = size
        self.kind = kind    # 'code', 'rodata', 'data', 'bss' or 'block'
        self.symbols = []   # symbols defined in it, in value order
        self.offsets = {}   # symbol -> its offset in the section
        self.map_syms = []  # (key, name) of those the map knows
        self.key = None
        self.nobits = False # a C bss object keyed in the image's bss
        self.pattern = None
        self.why = None     # how it was keyed, or why it was not
        self.follows = None # the section it trails (same key)
        self.refs = []      # (referencing Section, is_call) from relocations
        self.fixed = False  # placed by kernel.ld itself (SCRIPT_PLACED)
        self.map_segment = False  # a dpc section keyed by its map segment
        self.align = 1      # sh_addralign

    @property
    def label(self):
        return '%s(%s)' % (self.obj, self.name)

    @property
    def addr_taken(self):
        """Referenced other than by a call or branch: its address escapes
        (a pointer in data, `lea'/`pea'/`move.l #'), so it may be reached
        from anywhere, interrupt level included."""
        return any(not call for r, call in self.refs)


def section_kind(name):
    """The kind of an input section the layout orders, or None."""
    if name == '.text' or name.startswith('.text.'):
        return 'code'
    if name.startswith(('.moddata.', '.bss.moddata.')):
        return 'block'
    if name.startswith('.rodata.'):
        return 'rodata'
    if name.startswith('.data.'):
        return 'data'
    if name.startswith('.bss.'):
        return 'bss'
    return None


def is_code_section(name):
    return section_kind(name) == 'code'


def is_c_bss_section(name):
    """A C object's own zero-filled section (-fdata-sections), not a module
    data block."""
    return section_kind(name) == 'bss'


# 68000 opcode words that make a relocated operand a call or a branch
# target rather than an address that escapes: jsr/jmp abs.l (R_68K_32),
# jsr/jmp (d16,PC) and bra/bsr/Bcc.w (R_68K_PC16), bsr.s/Bcc.s (R_68K_PC8),
# and `lea sym,An' (see is_call).  Anything else (`pea', `move.l #sym',
# a pointer in data) lets the address escape.
CALL_OPS_ABS = (0x4EB9, 0x4EF9)
CALL_OPS_PC16 = (0x4EBA, 0x4EFA)


def is_call(elf_sec, contents, offset, typ):
    if typ == rfc_elf.R_68K_32 and offset >= 2:
        op = int.from_bytes(contents[offset - 2:offset], 'big')
        if op in CALL_OPS_ABS:
            return True
        # `lea sym,An' counts as a call when the routine also has a
        # `jsr (An)' or `jmp (An)': gcc loads a routine it calls more than
        # once into an address register.  (A crude scan of the section's
        # words; without one the address is taken to escape.)
        if (op & 0xF1FF) == 0x41F9:
            an = (op >> 9) & 7
            want = {0x4E90 | an, 0x4ED0 | an}
            return any(int.from_bytes(contents[i:i + 2], 'big') in want
                       for i in range(0, len(contents) - 1, 2))
        return False
    if typ == rfc_elf.R_68K_PC16 and offset >= 2:
        op = int.from_bytes(contents[offset - 2:offset], 'big')
        return op in CALL_OPS_PC16 or (op & 0xF0FF) == 0x6000
    if typ == rfc_elf.R_68K_PC8 and offset >= 1:
        return (contents[offset - 1] & 0xF0) == 0x60
    return False


def read_object(obj):
    """The ordered sections of one object (code, C .rodata/.data/.bss and
    module data blocks), each with the symbols it defines, the globals it
    defines, and its outgoing references: ([Section], {global: Section},
    [(from Section, Section or global name, is_call)])."""
    elf = rfc_elf.Elf(obj)
    secs = {}
    for s in elf.sections:
        kind = section_kind(s.name)
        if kind and s.alloc and s.size:
            secs[s.index] = Section(obj, s.name, s.size, kind)
            secs[s.index].align = max(1, s.align)
    if not secs:
        return [], {}, []
    syms = elf.symbols()
    named = []
    glob = {}
    for name, value, _, info, shndx in syms:
        if shndx not in secs or not name or name.startswith('.L'):
            continue
        if (info & 0xF) in (3, 4):      # STT_SECTION, STT_FILE
            continue
        named.append((value, name, shndx))
        if (info >> 4) != 0:            # global or weak
            glob.setdefault(name, secs[shndx])
    for value, name, shndx in sorted(named):
        secs[shndx].symbols.append(name)
        secs[shndx].offsets.setdefault(name, value)
    refs = []
    for rs in elf.sections:
        if rs.type != rfc_elf.SHT_RELA or rs.info not in secs:
            continue
        frm = secs[rs.info]
        tsec = elf.sections[rs.info]
        contents = elf.contents(tsec)
        for i in range(rs.size // 12):
            r_offset, r_info, _ = struct.unpack_from('>IIi', elf.data,
                                                     rs.offset + i * 12)
            symi, typ = r_info >> 8, r_info & 0xFF
            if symi >= len(syms):
                continue
            name, _, _, info, shndx = syms[symi]
            call = frm.kind == 'code' and \
                is_call(tsec, contents, r_offset, typ)
            if shndx in secs:
                to = secs[shndx]
            elif shndx == 0 and name:
                to = name
            else:
                continue
            refs.append((frm, to, call))
    return list(secs.values()), glob, refs


# ---------------------------------------------------------------------------
# Placing what the map does not name
# ---------------------------------------------------------------------------
#
# In the image every wired module's code and data lay below .TEXT
# (OS_PROC_UNWIRED, map 0xE38000) and never reached the paging file; the
# unwired modules' lay above it.  A section of ours that defines no map
# symbol (a file-static helper, a C object under a name of ours, a const
# cell) has no map position of its own, so it is placed by its OWNER: the
# sections that reference it (relocations), which the map does place.
#
#   - The owner is the referencer in the most-resident place, then the
#     lowest map key: permanently wired (below the boot-only part, or past
#     OS_DATA_END) before the ranges the kernel wires on demand
#     (SPECIAL_RANGES: the disk ranges a disked node keeps, the shutdown,
#     PEB, NETLOG, RING and routing ranges MST_$WIRE_AREA wires), before
#     unwired, before the boot-only part os_$start_proc2 frees.  So
#     anything a wired routine reaches is wired, as it must be (interrupt
#     level, spin locks), and only what unwired code alone reaches is
#     paged.
#   - Code and const data follow the owner (same key, after it).
#   - Writable data and C bss cannot follow code: the type-4 boot makes
#     the code read-only (0x00E33B88).  They go to the owner module's
#     data segment of the map, found by name (the map segment holding the
#     owner, e.g. `I E5D050 FILE_' -> `D E82128 FILE_') in the data
#     region that matches the owner's (WIRED_DATA, OS_INIT_DATA, .DATA);
#     a module with no data segment there gets the end of that region.
#   - Code whose address escapes (a pointer in data, `lea'/`pea') may be
#     called from anywhere: it is wired, following a wired referencer if
#     there is one, else with the run-time helpers (RUNTIME_KEY).
#   - Owners are resolved in dependency order (a static table referenced
#     only by a helper waits for the helper); a cycle is broken with the
#     owners known so far.  What nothing references follows its object's
#     most-resident placed section; what is left has no owner at all and is
#     kept with the run-time helpers (wired).
#
# Explicit image addresses (DATA_ANCHORS) win over all of this.

C_WIRED, C_SPECIAL, C_UNWIRED, C_INIT = range(4)
CLASS_NAMES = ['wired', 'wired-on-demand', 'unwired', 'boot-only']

# Map ranges the kernel wires at run time (OS_$INIT's disked keep-wired
# test, MST_$WIRE_AREA): (code start, code end, data start, data end) of
# the map, ends exclusive; a module's code in the first range keeps its
# data in the second.
SPECIAL_PAIRS = {}
SPECIAL_PAIRS[2] = [
    # OS_DISK_PROC .. OS_DISK_END; OS_DISK_DATA (VTOC_) .. SVC_CATCHER
    (0x00E3824C, 0x00E3E746, 0x00E784D0, 0x00E7B044),
    # OS_PROC_SHUTWIRED .. OS_SHUTWIRED_END; STOP_WATCH,
    # OS_DATA_SHUTWIRED (FILE_) .. OS_DATA_SHUTWIRED_END (DTTY_ASM)
    (0x00E5D050, 0x00E6D6FE, 0x00E81814, 0x00E82740),
    # PEB_WIRED .. PEB_WIRED_END; the PEB_WIRED data segment
    (0x00E70810, 0x00E70A3E, 0x00E84E80, 0x00E854D8),
    # NETLOG code; the NETLOG data segment
    (0x00E71914, 0x00E71D7A, 0x00E85684, 0x00E85708),
    # RING_PROC_START .. RING_PROC_END; RING_DATA_START .. RING_DATA_END
    (0x00E75400, 0x00E77F34, 0x00E86400, 0x00E869D0),
    # ETHER_PROC_START .. ETHER_PROC_END; ETHER_DATA
    (0x00E78000, 0x00E78018, 0x00E86C00, 0x00E86C08),
    # RTWIRED_CODE; RTWIRED_DATA
    (0x00E87000, 0x00E87D68, 0x00E87D68, 0x00E88228),
    # PBU_WIRED_PROC; PBU_WIRED_DATA (and the SCSI/MONO/COLOR cells)
    (0x00E88400, 0x00E88460, 0x00E88460, 0x00E88834),
]
# The SAU3's: the same eight in the same order (SPECIAL_DATA_MARKED
# indexes them), then the ranges of the SAU3's own drivers that their
# acquire routines wire (mst_$wire_area by the marks of TEXT_MARKS[3]).
SPECIAL_PAIRS[3] = [
    # OS_DISK_PROC 0xE3824C .. OS_DISK_PROC_END (I E3DE78 OS_DISK_END);
    # OS_DISK_DATA (D E79CD0 VTOC_) .. D E7C708 SVC_CATCHER
    (0x00E3824C, 0x00E3DE7A, 0x00E79CD0, 0x00E7C708),
    # OS_PROC_SHUTWIRED 0xE5DFC4 .. I E6E620 OS_SHUTWIRED_END; D E82F28
    # STOP_WATCH, OS_DATA_SHUTWIRED (D E8383C FILE_) .. D E83D30 DTTY_ASM
    (0x00E5DFC4, 0x00E6E622, 0x00E82F28, 0x00E83D30),
    # I E6E6C0 PEB_WIRED .. I E6E720 PEB_WIRED_END; no PEB wired data
    (0x00E6E6C0, 0x00E6E722, 0x00E8417C, 0x00E8417C),
    # I E72FE8 NETLOG size = 464 (+ I E7344C NETLOG); D E84730 NETLOG
    # size = 84
    (0x00E72FE8, 0x00E7344E, 0x00E84730, 0x00E847B4),
    # D62 E76C00 RING_PROC_START .. D61 E79724 RING_PROC_END; D60 E86800
    # RING_DATA_START .. D59 E86DD0 RING_DATA_END
    (0x00E76C00, 0x00E79724, 0x00E86800, 0x00E86DD0),
    # D55 E79800 ETHER_PROC_START .. D54 E79814 ETHER_PROC_END (size 4);
    # D53 E87000 ETHER_DATA_START .. D52 E87004 ETHER_DATA_END (size 4)
    (0x00E79800, 0x00E79818, 0x00E87000, 0x00E87008),
    # I12 E87400 RTWIRED_CODE size = D68; D34 E88168 RTWIRED_DATA ..
    # E88628 RTWIRED_DATA_END
    (0x00E87400, 0x00E88168, 0x00E88168, 0x00E88628),
    # PBU_$PAGE_START (D35 E89400 PBU_PAGE) and I16 E89BA4 PBU_WIRED_PROC
    # size = 4B0; D36 E8A054 PBU_WIRED_DATA (and the SCSI/MONO/COLOR cells)
    # .. RELOC
    (0x00E89400, 0x00E8A054, 0x00E8A054, 0x00E8A434),
    # SM_C_$PROC_START (I E6EDD0 SM_C size = D58) .. SM_C_$PROC_END
    # 0xE6FB96; SM_C_$DATA_START = SM_C_$DATA_END = 0xE844D8 (no data)
    (0x00E6EDD0, 0x00E6FB96, 0x00E844D8, 0x00E844D8),
    # MT_$PROC_START (I E70FD8 MT_$SIO size = 2C0) .. MT_$PROC_END
    # 0xE7129A; the MT page (D38 E88800 MT_PAGE size = C00)
    (0x00E70FD8, 0x00E7129A, 0x00E88800, 0x00E89400),
    # LPR_$PROC_START (I E6E724 LPR_ size = 3C0) .. LPR_$PROC_END
    # 0xE6EDCD (I E6EDCC LPR_END_ADDR); LPR_$DATA_START (D E8417C LPR_)
    # .. LPR_$DATA_END 0xE844D7, with LPR_ASM and CBUF's block
    (0x00E6E724, 0x00E6EDD0, 0x00E8417C, 0x00E844D8),
    # IIC_$PROC_START (I18 E85400 IIC_AQWRD_PROC size = E10) ..
    # IIC_$PROC_END (D40 E86210 IIC_AQWRD_DATA2); .. IIC_$DATA_END
    # 0xE865D0 (D39 E865C8 IIC_AQWRD_DATA size = 8)
    (0x00E85400, 0x00E86210, 0x00E86210, 0x00E865D0),
]
# The SAU5's: the same eight in the same order (SPECIAL_DATA_MARKED
# indexes them), then the ranges of the SAU5's own drivers that their
# acquire routines wire (mst_$wire_area by the marks of TEXT_MARKS[5]).
SPECIAL_PAIRS[5] = [
    # OS_DISK_PROC 0xE3824C .. OS_DISK_PROC_END (I E3DE78 OS_DISK_END);
    # OS_DISK_DATA (D E7F8D0 VTOC_) .. D E82308 SVC_CATCHER
    (0x00E3824C, 0x00E3DE7A, 0x00E7F8D0, 0x00E82308),
    # OS_PROC_SHUTWIRED 0xE5E72C .. I E6F978 OS_SHUTWIRED_END; D E88B30
    # STOP_WATCH, OS_DATA_SHUTWIRED (D E89444 FILE_) .. D E89AB8 DTTY_ASM
    (0x00E5E72C, 0x00E6F97A, 0x00E88B30, 0x00E89AB8),
    # I E746FC PEB_WIRED .. I E74928 PEB_WIRED_END; D E8C994 PEB_WIRED
    # size = 658
    (0x00E746FC, 0x00E7492A, 0x00E8C994, 0x00E8CFEC),
    # I E78A88 NETLOG size = 464 (+ I E78EEC NETLOG); D E8DEB0 NETLOG
    # size = 84
    (0x00E78A88, 0x00E78EEE, 0x00E8DEB0, 0x00E8DF34),
    # D61 E7C800 RING_PROC_START .. D60 E7F1B4 RING_PROC_END; D59 E8EC00
    # RING_DATA_START .. D58 E8F1D0 RING_DATA_END
    (0x00E7C800, 0x00E7F1B4, 0x00E8EC00, 0x00E8F1D0),
    # D54 E7F400 ETHER_PROC_START .. D53 E7F414 ETHER_PROC_END (size 4);
    # D52 E8F400 ETHER_DATA_START .. D51 E8F404 ETHER_DATA_END (size 4)
    (0x00E7F400, 0x00E7F418, 0x00E8F400, 0x00E8F408),
    # I12 E8F800 RTWIRED_CODE size = D68; D34 E90568 RTWIRED_DATA ..
    # E90A28 RTWIRED_DATA_END
    (0x00E8F800, 0x00E90568, 0x00E90568, 0x00E90A28),
    # PBU_$PAGE_START (D36 E91800 PBU_PAGE) and I16 E91F70 PBU_WIRED_PROC
    # size = 4AC; D37 E9241C PBU_WIRED_DATA (and the SCSI/MONO/COLOR cells)
    # .. RELOC: PBU_$WIRE_PBU wires PBU_$PAGE_START .. PBU_$DATA_END
    # (pbu/pbu.ins.pas)
    (0x00E91800, 0x00E9241C, 0x00E9241C, 0x00E92834),
    # SM_C_$PROC_START (I E74934 SM_C size = D5C) .. SM_C_$PROC_END
    # 0xE756FE; SM_C_$DATA_START = SM_C_$DATA_END = 0xE8CFEC (no data)
    (0x00E74934, 0x00E756FE, 0x00E8CFEC, 0x00E8CFEC),
    # MT_$PROC_START (I E76B48 MT_$SIO size = 2C0) .. MT_$PROC_END
    # 0xE76E0A; the MT page MT_$PAGE_START .. (D39 E90C00 MT_PAGE size =
    # C00): MT_$ACQUIRE wires both (mt/mt.ins.pas)
    (0x00E76B48, 0x00E76E0A, 0x00E90C00, 0x00E91800),
    # CT_$PROC_START (I E76EAC CT size = DC0) .. CT_$PROC_END 0xE77C6E;
    # CT_$DATA_START (D E8CFEC CT size = D18) .. CT_$DATA_END 0xE8DD04
    # (ct/acquire.pas)
    (0x00E76EAC, 0x00E77C6E, 0x00E8CFEC, 0x00E8DD04),
]
# The SAU8's: the same eight in the same order (PBU's as the SAU5's, from
# PBU_$PAGE_START), then its drivers' ranges as the SAU9's (CT's, the
# 802.5 ring's, the SCSI stubs').
SPECIAL_PAIRS[8] = [
    # OS_DISK_PROC 0x3C4024C .. OS_DISK_PROC_END; OS_DISK_DATA (D 3C8D8D0
    # VTOC_) .. D 3C90504 SVC_CATCHER
    (0x03C4024C, 0x03C468FA, 0x03C8D8D0, 0x03C90504),
    # OS_PROC_SHUTWIRED 0x3C66798 .. OS_PROC_SHUTWIRED_END; D 3C9A304
    # STOP_WATCH, OS_DATA_SHUTWIRED (D 3C9AC18 FILE_) .. D 3C9B230 DTTY_ASM
    (0x03C66798, 0x03C76AEE, 0x03C9A304, 0x03C9B230),
    # I 3C79F50 PEB_WIRED .. PEB_WIRED_END; no PEB wired data
    (0x03C79F50, 0x03C79FB2, 0x03C9D43C, 0x03C9D43C),
    # I 3C7C1DC NETLOG (+ I 3C7C62C NETLOG); D 3C9E32C NETLOG size = 84
    (0x03C7C1DC, 0x03C7C62E, 0x03C9E32C, 0x03C9E3B0),
    # RING_PROC_START .. RING_PROC_END; RING_DATA_START .. RING_DATA_END
    (0x03C81400, 0x03C847FC, 0x03C9F000, 0x03C9FB48),
    # ETHER_PROC_START .. ETHER_PROC_END (size 4); ETHER_DATA_START ..
    # ETHER_DATA_END (size 4)
    (0x03C84800, 0x03C88EE4, 0x03C9FC00, 0x03C9FCE8),
    # I12 3CA3800 RTWIRED_CODE size = D3C; D39 3CA453C RTWIRED_DATA ..
    # RTWIRED_DATA_END
    (0x03CA3800, 0x03CA453C, 0x03CA453C, 0x03CA49FC),
    # PBU_$PAGE_START (D44 3CA4C00 PBU_PAGE) and I17 3CA5664
    # PBU_WIRED_PROC size = 654; D45 3CA5CB8 PBU_WIRED_DATA ..
    # PBU_$DATA_END
    (0x03CA4C00, 0x03CA5CB8, 0x03CA5CB8, 0x03CA5FC4),
    # CT_$PROC_START (I 3C7A068 CT) .. CT_$PROC_END 0x3C7B3D6;
    # CT_$DATA_START (D 3C9D43C CT) .. CT_$DATA_END 0x3C9E180
    (0x03C7A068, 0x03C7B3D6, 0x03C9D43C, 0x03C9E180),
    # RING8025_PROC_ST .. RING8025_PROC_EN (size 4); RING8025_DATA_ST ..
    # RING8025_DATA_EN (size 4)
    (0x03C89000, 0x03C8D75C, 0x03CA2800, 0x03CA296C),
    # I18 3CA6000 SCSI_WIRED_PROC size = 4; D46 3CA6004 SCSI_WIRED_DATA
    # size = 4
    (0x03CA6000, 0x03CA6004, 0x03CA6004, 0x03CA6008),
]
# The SAU9's: the same eight in the same order, then its drivers' ranges
# (CT's, the 802.5 ring's, the SCSI driver's wired code and data).
SPECIAL_PAIRS[9] = [
    # OS_DISK_PROC 0x3C44024C .. OS_DISK_PROC_END; OS_DISK_DATA (D 3C4898D0
    # VTOC_) .. D 3C48C308 SVC_CATCHER
    (0x3C44024C, 0x3C445C2E, 0x3C4898D0, 0x3C48C308),
    # OS_PROC_SHUTWIRED 0x3C46400C .. OS_PROC_SHUTWIRED_END; D 3C499F98
    # STOP_WATCH, OS_DATA_SHUTWIRED (D 3C49A8AC FILE_) .. D 3C49AEC4 DTTY_ASM
    (0x3C46400C, 0x3C47434A, 0x3C499F98, 0x3C49AEC4),
    # I 3C4770E0 PEB_WIRED .. PEB_WIRED_END; no PEB wired data
    (0x3C4770E0, 0x3C477142, 0x3C49D0BC, 0x3C49D0BC),
    # I 3C47930C NETLOG (+ I 3C47975C NETLOG); D 3C49DFF4 NETLOG size = 84
    (0x3C47930C, 0x3C47975E, 0x3C49DFF4, 0x3C49E078),
    # RING_PROC_START .. RING_PROC_END; RING_DATA_START .. RING_DATA_END
    (0x3C47D000, 0x3C4803F0, 0x3C49EC00, 0x3C49F748),
    # ETHER_PROC_START .. ETHER_PROC_END (size 4); ETHER_DATA_START ..
    # ETHER_DATA_END (size 4)
    (0x3C480400, 0x3C484B0C, 0x3C49F800, 0x3C49F8E8),
    # I13 3C4A3400 RTWIRED_CODE size = D3C; D40 3C4A413C RTWIRED_DATA ..
    # RTWIRED_DATA_END
    (0x3C4A3400, 0x3C4A413C, 0x3C4A413C, 0x3C4A45FC),
    # I17 3C4A4800 PBU_WIRED_PROC size = 60; D88 3C4A4860 PBU_WIRED_DATA ..
    # PBU_$DATA_END
    (0x3C4A4800, 0x3C4A4860, 0x3C4A4860, 0x3C4A4B60),
    # CT_$PROC_START (I 3C4771F8 CT) .. CT_$PROC_END 0x3C478506;
    # CT_$DATA_START (D 3C49D0BC CT) .. CT_$DATA_END 0x3C49DE48
    (0x3C4771F8, 0x3C478506, 0x3C49D0BC, 0x3C49DE48),
    # RING8025_PROC_ST .. RING8025_PROC_EN (size 4); RING8025_DATA_ST ..
    # RING8025_DATA_EN (size 4)
    (0x3C484C00, 0x3C48941C, 0x3C4A2400, 0x3C4A2570),
    # I18 3C4A4C00 SCSI_WIRED_PROC size = 2640; D43 3C4A7240
    # SCSI_WIRED_DATA size = 374
    (0x3C4A4C00, 0x3C4A7240, 0x3C4A7240, 0x3C4A75B4),
]
SPECIAL_RANGES = {
    sau: [(cs, ce) for cs, ce, _, _ in pairs] +
    [(ds, de) for _, _, ds, de in pairs]
    for sau, pairs in SPECIAL_PAIRS.items()}

# The map's permanent code regions and the data region of the same
# residency: (code start, code end, data start, data end, class).
CODE_TO_DATA = {}
CODE_TO_DATA[2] = [
    (0x00E00800, 0x00E1DC00, 0x00E1DC00, 0x00E2F000),  # WIRED_PROC/DATA
    (0x00E2F000, 0x00E35000, 0x00E35000, 0x00E38000),  # OS_INIT_PROC/DATA
    (0x00E38000, 0x00E78400, 0x00E78400, 0x00E88834),  # .TEXT../.DATA
    (0x00E87000, 0x00E87D68, 0x00E87D68, 0x00E88228),  # RTWIRED
    (0x00E88400, 0x00E88460, 0x00E88460, 0x00E88834),  # PBU_WIRED
]
CODE_TO_DATA[3] = [
    # I 4 E00800 WIRED_PROC; D24 E1CC00 WIRED_DATA .. I 5 E2DC00
    (0x00E00800, 0x00E1CC00, 0x00E1CC00, 0x00E2DC00),
    # I 5 E2DC00 OS_INIT_PROC; D25 E33400 OS_INIT_DATA .. I 1 E38000
    (0x00E2DC00, 0x00E33400, 0x00E33400, 0x00E38000),
    # I 1 E38000 .TEXT; D21 E79C00 .DATA .. I20 E8A434 RELOC
    (0x00E38000, 0x00E79C00, 0x00E79C00, 0x00E8A434),
    # I18 E85400 IIC_AQWRD_PROC; D40 E86210 IIC_AQWRD_DATA2 .. the end of
    # D39 E865C8 IIC_AQWRD_DATA
    (0x00E85400, 0x00E86210, 0x00E86210, 0x00E865D0),
    # I12 E87400 RTWIRED_CODE; D34 E88168 RTWIRED_DATA
    (0x00E87400, 0x00E88168, 0x00E88168, 0x00E88628),
    # D35 E89400 PBU_PAGE (PBU_ASM) and I16 E89BA4 PBU_WIRED_PROC; D36
    # E8A054 PBU_WIRED_DATA
    (0x00E89400, 0x00E8A054, 0x00E8A054, 0x00E8A434),
]
CODE_TO_DATA[5] = [
    # I 4 E00800 WIRED_PROC; D24 E1E800 WIRED_DATA .. I 5 E30400
    (0x00E00800, 0x00E1E800, 0x00E1E800, 0x00E30400),
    # I 5 E30400 OS_INIT_PROC; D25 E37800 OS_INIT_DATA .. I 1 E38000
    (0x00E30400, 0x00E37800, 0x00E37800, 0x00E38000),
    # I 1 E38000 .TEXT; D21 E7F800 .DATA .. I20 E92834 RELOC
    (0x00E38000, 0x00E7F800, 0x00E7F800, 0x00E92834),
    # I12 E8F800 RTWIRED_CODE; D34 E90568 RTWIRED_DATA
    (0x00E8F800, 0x00E90568, 0x00E90568, 0x00E90A28),
    # D36 E91800 PBU_PAGE (PBU_ASM) and I16 E91F70 PBU_WIRED_PROC; D37
    # E9241C PBU_WIRED_DATA
    (0x00E91800, 0x00E9241C, 0x00E9241C, 0x00E92834),
]
CODE_TO_DATA[8] = [
    # I 4 3C00C00 WIRED_PROC; D25 3C1F400 WIRED_DATA .. I 5 3C31C00
    (0x03C00C00, 0x03C1F400, 0x03C1F400, 0x03C31C00),
    # I 5 3C31C00 OS_INIT_PROC; D26 3C39400 OS_INIT_DATA .. I 1 3C40000
    (0x03C31C00, 0x03C39400, 0x03C39400, 0x03C40000),
    # I 1 3C40000 .TEXT; D22 3C8D800 .DATA .. I21 3CA65F8 RELOC
    (0x03C40000, 0x03C8D800, 0x03C8D800, 0x03CA65F8),
    # I12 3CA3800 RTWIRED_CODE; D39 3CA453C RTWIRED_DATA
    (0x03CA3800, 0x03CA453C, 0x03CA453C, 0x03CA49FC),
    # D44 3CA4C00 PBU_PAGE (PBU_ASM) and I17 3CA5664 PBU_WIRED_PROC; D45
    # 3CA5CB8 PBU_WIRED_DATA
    (0x03CA4C00, 0x03CA5CB8, 0x03CA5CB8, 0x03CA5FC4),
    # I18 3CA6000 SCSI_WIRED_PROC; D46 3CA6004 SCSI_WIRED_DATA
    (0x03CA6000, 0x03CA6004, 0x03CA6004, 0x03CA6008),
]
CODE_TO_DATA[9] = [
    # I 5 3C401C00 WIRED_PROC; D25 3C420800 WIRED_DATA .. I 6 3C434C00
    (0x3C401C00, 0x3C420800, 0x3C420800, 0x3C434C00),
    # I 6 3C434C00 OS_INIT_PROC; D26 3C43BC00 OS_INIT_DATA .. I 1 3C440000
    (0x3C434C00, 0x3C43BC00, 0x3C43BC00, 0x3C440000),
    # I 1 3C440000 .TEXT; D22 3C489800 .DATA .. I21 3C4A75D8 RELOC
    (0x3C440000, 0x3C489800, 0x3C489800, 0x3C4A75D8),
    # I13 3C4A3400 RTWIRED_CODE; D40 3C4A413C RTWIRED_DATA
    (0x3C4A3400, 0x3C4A413C, 0x3C4A413C, 0x3C4A45FC),
    # I17 3C4A4800 PBU_WIRED_PROC; D88 3C4A4860 PBU_WIRED_DATA
    (0x3C4A4800, 0x3C4A4860, 0x3C4A4860, 0x3C4A4B60),
    # I18 3C4A4C00 SCSI_WIRED_PROC; D43 3C4A7240 SCSI_WIRED_DATA
    (0x3C4A4C00, 0x3C4A7240, 0x3C4A7240, 0x3C4A75B4),
]
WIRED_DATA_REGION = {
    2: (0x00E1DC00, 0x00E2F000),
    3: (0x00E1CC00, 0x00E2DC00),    # D24 E1CC00 WIRED_DATA .. I 5 E2DC00
    5: (0x00E1E800, 0x00E30400),    # D24 E1E800 WIRED_DATA .. I 5 E30400
    8: (0x03C1F400, 0x03C31C00),    # D25 3C1F400 WIRED_DATA .. I 5 3C31C00
    9: (0x3C420800, 0x3C434C00),    # D25 3C420800 WIRED_DATA .. I 6 3C434C00
}
UNWIRED_DATA_REGION = {
    2: (0x00E78400, 0x00E88834),
    3: (0x00E79C00, 0x00E8A434),    # D21 E79C00 .DATA .. I20 E8A434 RELOC
    5: (0x00E7F800, 0x00E92834),    # D21 E7F800 .DATA .. I20 E92834 RELOC
    8: (0x03C8D800, 0x03CA65F8),    # D22 3C8D800 .DATA .. I21 3CA65F8 RELOC
    9: (0x3C489800, 0x3C4A75D8),    # D22 3C489800 .DATA .. I21 3C4A75D8 RELOC
}

# Where writable data goes when no data segment of its module is found:
# the end of the region's data, before the next map item.
LATE = 1 << 30
REGION_DATA_END_KEY = {
    2: {
        C_WIRED: (0x00E2E09F, LATE),    # end of WIRED_DATA (D24, 0xE2E0A0)
        C_UNWIRED: (0x00E85707, LATE),  # end of .DATA (D21, 0xE85708)
    },
    3: {
        # D24 E1CC00 WIRED_DATA size = 100F4: its end is 0xE2CCF4
        C_WIRED: (0x00E2CCF3, LATE),
        # D21 E79C00 .DATA size = ABB4: its end is 0xE847B4
        C_UNWIRED: (0x00E847B3, LATE),
    },
    5: {
        # D24 E1E800 WIRED_DATA size = 10CC4: its end is 0xE2F4C4
        C_WIRED: (0x00E2F4C3, LATE),
        # D21 E7F800 .DATA size = E734: its end is 0xE8DF34
        C_UNWIRED: (0x00E8DF33, LATE),
    },
    8: {
        # D25 3C1F400 WIRED_DATA size = 11164: its end is 0x3C30564
        C_WIRED: (0x03C30563, LATE),
        # D22 3C8D800 .DATA size = 10BB0: its end is 0x3C9E3B0
        C_UNWIRED: (0x03C9E3AF, LATE),
    },
    9: {
        # D25 3C420800 WIRED_DATA size = 12E00: its end is 0x3C433600
        C_WIRED: (0x3C4335FF, LATE),
        # D22 3C489800 .DATA size = 14878: its end is 0x3C49E078
        C_UNWIRED: (0x3C49E077, LATE),
    },
}

# The run-time slot: whatever has no owner, and escaping code with no
# wired referencer.  The image's own arithmetic helpers are the wired
# `I E0ABD4 M$ARITH size 1DC' (dpc's runtime m_arith.o, placed by its map
# symbols); the slot is where it ends (before `I E0ADB0 MEM_'), wired.
# The kernel does not link libgcc, so the slot itself emits no input
# statement.
RUNTIME_KEY = {
    2: (0x00E0ADB0, -1),
    3: (0x00E0AE5C, -1),    # I E0AC80 M$ARITH size = 1DC; I E0AE5C MEM_
    5: (0x00E0AF5C, -1),    # I E0AD80 M$ARITH size = 1DC; I E0AF5C MEM_
    8: (0x03C0BBC8, -1),    # I 3C0B9EC M$ARITH size = 1DC; I 3C0BBC8 MEM_
    9: (0x3C40CC00, -1),    # I 3C40CA24 M$ARITH size = 1DC; I 3C40CC00 MEM_
}

# Objects holding image data under names the map does not use, keyed by
# the image address of their first byte.  The Pascal build defines its
# data in its modules, whose blocks the map keys (dpc_blocks), so the SAU2
# and SAU5 have none.  A key
# in the image's bss (past RELOC) makes a bss object NOBITS there.
DATA_ANCHORS = {2: {}, 3: {}, 5: {}, 8: {
    # mono/, color4/, color5/: the display drivers' initialized overlay
    # sections, the map's numbered sections after SCSI_WIRED_DATA (names
    # cut at 16 characters; the COLOR6_ and COLOR7_ sections after them
    # have no module)
    '.data.overlay.MONO_$WIRED_DATA': 0x03CA6008,     # D43 MONO_$WIRED_DATA, 2D8
    '.data.overlay.MONO_END_DATA': 0x03CA62E0,        # D87 MONO_END_DATA, 4
    '.data.overlay.COLOR4_$WIRED_DATA': 0x03CA62E4,   # D41 COLOR4_$WIRED_DA, 174
    '.data.overlay.COLOR4_END_DATA': 0x03CA6458,      # D84 COLOR4_END_DATA, 4
    '.data.overlay.COLOR5_$WIRED_DATA': 0x03CA645C,   # D42 COLOR5_$WIRED_DA, 184
    '.data.overlay.COLOR5_END_DATA': 0x03CA65E0,      # D85 COLOR5_END_DATA, 4
}, 9: {
    # mono9/mono9_desc.pas: dpc's initialized overlay section
    # MONO9_$WIRED_DATA, the map's `D42 3C43399C MONO9_$WIRED_DAT size = C8'
    # (the map truncates the name; no symbol of it)
    '.data.overlay.MONO9_$WIRED_DATA': 0x3C43399C,
}}


# The data part of each SPECIAL_PAIRS entry whose run-time wired extent
# lies between link marks the generator emits (so a map data segment inside
# it is wired with it): the disked keep-wired data (OS_DISK_DATA ..
# OS_DISK_DATA_END), what OS_$SHUTDOWN wires (OS_DATA_SHUTWIRED ..
# OS_DATA_SHUTWIRED_END; STOP_$WATCH .. OS_DATA_SHUTWIRED is STOP's own
# range, not wired at shutdown) and RING_DATA_START .. RING_DATA_END.
# The SAU3's also LPR_'s and IIC's (entries 10 and 11), the SAU5's CT's
# data (CT_$DATA_START .. CT_$DATA_END), its entry 10.
SPECIAL_DATA_MARKED = {
    2: {
        0: (0x00E784D0, 0x00E7B044),
        1: (0x00E82128, 0x00E82740),
        4: (0x00E86400, 0x00E869D0),
    },
    3: {
        0: (0x00E79CD0, 0x00E7C708),    # VTOC_ .. SVC_CATCHER
        1: (0x00E8383C, 0x00E83D30),    # FILE_ .. DTTY_ASM
        4: (0x00E86800, 0x00E86DD0),    # RING_DATA_START .. RING_DATA_END
        10: (0x00E8417C, 0x00E844D8),   # LPR_$DATA_START .. LPR_$DATA_END
        11: (0x00E86210, 0x00E865D0),   # IIC_$PROC_END .. IIC_$DATA_END
    },
    5: {
        0: (0x00E7F8D0, 0x00E82308),    # VTOC_ .. SVC_CATCHER
        1: (0x00E89444, 0x00E89AB8),    # FILE_ .. DTTY_ASM
        4: (0x00E8EC00, 0x00E8F1D0),    # RING_DATA_START .. RING_DATA_END
        10: (0x00E8CFEC, 0x00E8DD04),   # CT_$DATA_START .. CT_$DATA_END
    },
    8: {
        0: (0x03C8D8D0, 0x03C90504),    # VTOC_ .. SVC_CATCHER
        1: (0x03C9AC18, 0x03C9B230),    # FILE_ .. DTTY_ASM
        4: (0x03C9F000, 0x03C9FB48),    # RING_DATA_START .. RING_DATA_END
        8: (0x03C9D43C, 0x03C9E180),    # CT_$DATA_START .. CT_$DATA_END
    },
    9: {
        0: (0x3C4898D0, 0x3C48C308),    # VTOC_ .. SVC_CATCHER
        1: (0x3C49A8AC, 0x3C49AEC4),    # FILE_ .. DTTY_ASM
        4: (0x3C49EC00, 0x3C49F748),    # RING_DATA_START .. RING_DATA_END
        8: (0x3C49D0BC, 0x3C49DE48),    # CT_$DATA_START .. CT_$DATA_END
    },
}

# The residency bounds of addr_class: the start of the boot-only part
# (OS_INIT_PROC), the start of the unwired code (.TEXT) and OS_DATA_END,
# past which (the stacks, MMAP, ...) everything is wired.
CLASS_BOUNDS = {
    2: (0x00E2F000, 0x00E38000, 0x00EA9684),
    # I 5 E2DC00 OS_INIT_PROC, I 1 E38000 .TEXT, D92 EAB284 OS_DATA_END
    3: (0x00E2DC00, 0x00E38000, 0x00EAB284),
    # I 5 E30400 OS_INIT_PROC, I 1 E38000 .TEXT, D91 EB3684 OS_DATA_END
    5: (0x00E30400, 0x00E38000, 0x00EB3684),
    # I 5 3C31C00 OS_INIT_PROC, I 1 3C40000 .TEXT, D96 3CC7448 OS_DATA_END
    8: (0x03C31C00, 0x03C40000, 0x03CC7448),
    # I 6 3C434C00 OS_INIT_PROC, I 1 3C440000 .TEXT, D94 3C4C8428 OS_DATA_END
    9: (0x3C434C00, 0x3C440000, 0x3C4C8428),
}


def special_pair(addr):
    """Index in SPECIAL_PAIRS of the range holding `addr', or None."""
    for i, (cs, ce, ds, de) in enumerate(SPECIAL_PAIRS[SAU]):
        if cs <= addr < ce or ds <= addr < de:
            return i
    return None


def addr_class(addr):
    """Residency of a map address in the image."""
    init_start, text_start, data_end = CLASS_BOUNDS[SAU]
    if addr < init_start:
        return C_WIRED
    if addr < text_start:
        return C_INIT
    if addr >= data_end:            # OS_DATA_END: the stacks, MMAP, ...
        return C_WIRED
    for lo, hi in SPECIAL_RANGES[SAU]:
        if lo <= addr < hi:
            return C_SPECIAL
    return C_UNWIRED


def module_data_sections(objdump, objects):
    """{section name: object} for every .moddata.* / .bss.moddata.* section
    of the inputs."""
    found = {}
    for obj in objects:
        hdr = subprocess.run([objdump, '-h', obj], check=True,
                             capture_output=True, text=True).stdout
        for line in hdr.splitlines():
            f = line.split()
            if len(f) >= 7 and f[0].isdigit() and \
                    f[1].startswith(('.moddata.', '.bss.moddata.')):
                found.setdefault(f[1], obj)
    return found


class Layout:
    """The ordered placement of every code section, C data object and
    block."""

    def __init__(self, linkmap, blocks, objects, objdump):
        self.linkmap = linkmap
        self.blocks = blocks
        self.all = []       # every Section of the inputs
        self.errors = []
        glob = {}
        refs = []
        for obj in objects:
            secs, g, r = read_object(obj)
            self.all += secs
            for name, s in g.items():
                glob.setdefault(name, s)
            refs += r
        for frm, to, call in refs:
            if isinstance(to, str):
                to = glob.get(to)
                if to is None:
                    continue    # a symbol kernel.ld defines
            if to is not frm and frm.name not in SCRIPT_PLACED:
                to.refs.append((frm, call))
        block_by_section = {(b.src, b.section): b for b in blocks}
        for s in self.all:
            if s.kind == 'block' and (s.obj, s.name) in block_by_section:
                s.key = addr_key(block_by_section[(s.obj, s.name)].addr)
            if s.name in SCRIPT_PLACED:
                s.fixed = True
        self.sections = [s for s in self.all if s.kind == 'code']
        self.data = [s for s in self.all if s.kind in ('rodata', 'data')]
        self.bss = [s for s in self.all
                    if s.kind == 'bss' and not s.fixed]
        self._key_sections()
        self._key_data()
        self._key_bss()
        self._check_straddle()
        self._key_by_owner()
        self._check_residency()
        self._patterns()
        self._check_blocks(objdump, objects)
        self.windows, errs = bss_windows(linkmap)
        self.errors += errs
        self.overlays, errs = overlay_sections(linkmap, objects)
        self.errors += errs
        self._check_windows()

    def _check_windows(self):
        """Nothing else may be keyed inside a window's span: it has no
        object of its own to hold it."""
        keys = [(addr_key(b.addr)[0], b.where) for b in self.blocks]
        keys += [(s.key[0], s.label) for s in self.all
                 if s.key is not None and s.follows is None]
        keys += [(o.addr, o.where) for o in self.overlays]
        for w in self.windows:
            for a, what in keys:
                if w.addr <= a < w.addr + w.size:
                    self.errors.append('%s is keyed at 0x%06X, inside the '
                                       'window %s (0x%X bytes)'
                                       % (what, a, w.where, w.size))

    # -- sections the map (or an anchor) places --------------------------

    def _key_sections(self):
        lm = self.linkmap
        present = set()
        for s in self.sections:
            present.add(s.name)
            s.map_syms = sorted((lm.key(n), n) for n in s.symbols
                                if n in lm.symbols)
            if s.map_syms:
                s.key = s.map_syms[0][0]
            elif s.name in ANCHORS[SAU]:
                s.key = addr_key(ANCHORS[SAU][s.name])
            elif DPC_TEXT_RE.match(s.name):
                # a dpc code section defining no map symbol: its module's
                # code segment in that section of the map
                m = DPC_TEXT_RE.match(s.name)
                addr, _ = lm.module_segment('I', m.group('module'),
                                            m.group('section'))
                if addr is not None:
                    s.key = addr_key(addr)
                    s.map_segment = True
        for name in ANCHORS[SAU]:
            if name not in present:
                self.errors.append('ANCHORS names %s, which no link input '
                                   'defines' % name)

    def _key_data(self):
        """C .rodata / .data objects: by map symbol or DATA_ANCHORS."""
        lm = self.linkmap
        for s in self.data:
            s.map_syms = sorted((lm.key(n), n) for n in s.symbols
                                if n in lm.symbols)
            if s.map_syms:
                s.key = s.map_syms[0][0]
            elif s.name in DATA_ANCHORS[SAU]:
                s.key = addr_key(DATA_ANCHORS[SAU][s.name])
            if s.key and IMAGE_BSS_START[SAU] <= s.key[0] < IMAGE_BSS_END[SAU]:
                self.errors.append('%s has initial contents but its map '
                                   'position 0x%06X is in the image\'s bss'
                                   % (s.label, s.key[0]))

    def _key_bss(self):
        """C bss objects: a map symbol (or DATA_ANCHORS address) in the
        image's bss makes the object NOBITS there; one elsewhere places it
        in the loaded stream as file zeros."""
        lm = self.linkmap
        def image_bss(key):
            return IMAGE_BSS_START[SAU] <= key[0] < IMAGE_BSS_END[SAU]
        for s in self.bss:
            s.map_syms = sorted((lm.key(n), n) for n in s.symbols
                                if n in lm.symbols)
            if s.map_syms and all(image_bss(k) for k, _ in s.map_syms):
                s.key = s.map_syms[0][0]
            elif s.map_syms and any(image_bss(k) for k, _ in s.map_syms):
                self.errors.append('%s: map symbols inside and outside the '
                                   'image\'s bss 0x%06X..0x%06X'
                                   % (s.label, IMAGE_BSS_START[SAU],
                                      IMAGE_BSS_END[SAU]))
            elif s.map_syms:
                s.key = s.map_syms[0][0]
            elif s.name in DATA_ANCHORS[SAU]:
                s.key = addr_key(DATA_ANCHORS[SAU][s.name])
            if s.key is not None:
                s.nobits = image_bss(s.key)
        for b in self.blocks:
            if b.init and IMAGE_BSS_START[SAU] <= b.addr < IMAGE_BSS_END[SAU]:
                self.errors.append('%s: %s at 0x%08X has initial contents '
                                   'but lies in the image\'s bss (past '
                                   'RELOC 0x%06X), which has no file bytes'
                                   % (b.where, b.name, b.addr,
                                      IMAGE_BSS_START[SAU]))
        for name in DATA_ANCHORS[SAU]:
            if not any(s.name == name for s in self.data + self.bss):
                self.errors.append('DATA_ANCHORS names %s, which no link '
                                   'input defines' % name)

    def _check_straddle(self):
        # A C data object whose map symbol lies inside the map span of a
        # hand-written section (DI_$Q_HEAD 0xE20602, inside proc1_data.o's
        # PROC1_$TSVV .. PROC1_$CURRENT block) cannot be put between that
        # section's bytes: it trails the section, wired or not as the
        # section is, and leaves the order check (the image reaches it
        # PC-relative from the block's routines; ours by name).
        spans = [(t.map_syms[0][0], t.map_syms[-1][0], t)
                 for t in self.sections
                 if t.key is not None and len(t.map_syms) > 1]
        for s in self.data + self.bss:
            if s.key is None or not s.map_syms:
                continue
            for lo, hi, t in spans:
                if lo < s.key < hi:
                    s.why = 'map %s 0x%06X is inside %s: trails it' \
                        % (s.map_syms[0][1], s.key[0], t.label)
                    s.key = t.key
                    s.follows = t
                    s.nobits = False
                    s.map_syms = []
                    break
        # A section whose map symbols straddle other placed keys cannot be
        # wholly in order: an error (split the file per routine).
        for s in self.sections:
            if s.key is None or len(s.map_syms) < 2:
                continue
            others = sorted([t.key for t in self.sections + self.data
                             + self.bss
                             if t is not s and t.key is not None
                             and t.follows is None]
                            + [addr_key(b.addr) for b in self.blocks])
            for prev, cur in zip(s.map_syms, s.map_syms[1:]):
                i = bisect.bisect_right(others, prev[0])
                if i < len(others) and others[i] < cur[0]:
                    self.errors.append(
                        '%s: map symbols %s (0x%06X) and %s (0x%06X) '
                        'straddle another placed section or block; split '
                        'it one section per routine'
                        % (s.label, prev[1], prev[0][0], cur[1],
                           cur[0][0]))
                    break

    # -- everything else, by owner ----------------------------------------

    @staticmethod
    def _cls(s):
        return addr_class(s.key[0])

    def _choose(self, s, owners):
        """Key `s' from its keyed referencers `owners'."""
        best = min(owners, key=lambda r: (self._cls(r), r.key))
        cls = self._cls(best)
        why = 'owner %s (%s)' % (self._note(best), CLASS_NAMES[cls])
        if cls == C_SPECIAL and \
                len({special_pair(r.key[0]) for r in owners
                     if self._cls(r) == C_SPECIAL}) > 1:
            # Referenced from two ranges wired on demand (e.g. memcpy from
            # the shutdown code and from RING_$SEND_OS): neither range
            # covers the other's use, so it is wired for good.
            pairs = sorted({special_pair(r.key[0]) for r in owners
                            if self._cls(r) == C_SPECIAL})
            if s.kind == 'code':
                s.key = RUNTIME_KEY[SAU]
                s.why = 'owners in wired-on-demand ranges %s: with the ' \
                        'run-time helpers' % pairs
                return
            s.key = REGION_DATA_END_KEY[SAU][C_WIRED]
            s.why = 'owners in wired-on-demand ranges %s: end of the ' \
                    'wired data' % pairs
            return
        if s.kind == 'code':
            if s.addr_taken and cls not in (C_WIRED, C_SPECIAL):
                s.key = RUNTIME_KEY[SAU]
                s.why = 'address escapes, no wired referencer: with the ' \
                        'run-time helpers'
                return
            s.key = best.key
            s.follows = best
            s.why = why
            return
        # Data.  The boot-only part is freed by os_$start_proc2, and a
        # pointer to a datum may outlive the routine that took it, so data
        # whose only owners are boot-only goes to the unwired data.
        if cls == C_INIT:
            cls = C_UNWIRED
        addr = best.key[0]
        in_code = any(cs <= addr < ce for cs, ce, _, _ in CODE_TO_DATA[SAU]) \
            or any(cs <= addr < ce for cs, ce, _, _ in SPECIAL_PAIRS[SAU])
        if self._cls(best) != C_INIT and (s.kind == 'rodata'
                                          or not in_code):
            # const data with a resident owner trails it (read-only
            # among code is fine); anything whose owner is data already
            # trails that
            s.key = best.key
            s.follows = best
            s.why = why
            return
        # Writable data never goes among code (the type-4 boot write-
        # protects it, 0x00E33B88): the module's data segment of the map in
        # the data region of the owner's residency.
        if cls == C_SPECIAL:
            # only where the run-time wired extent is delimited by link
            # marks that the data segments lie between (SPECIAL_DATA_MARKED);
            # the other ranges wire one named object (PEB_$WIRED_DATA_START,
            # NETLOG_$DATA, up to ROUTE_$RTWIRED_DATA) and data placed after
            # it would not be wired with it: those go to the wired data
            pair = special_pair(addr)
            regions = [SPECIAL_DATA_MARKED[SAU][pair]] \
                if pair in SPECIAL_DATA_MARKED[SAU] else []
            if not regions:
                cls = C_WIRED
                regions = [WIRED_DATA_REGION[SAU]]
        elif cls == C_WIRED:
            regions = [WIRED_DATA_REGION[SAU]]
        else:
            regions = [UNWIRED_DATA_REGION[SAU]]
        mod = s.obj.split('build/sau%d/' % SAU, 1)[-1].split('/')[0].upper()
        owner_seg = self.linkmap.segment_of(addr)

        def named(seg):
            n = seg.rstrip('_')
            return n == mod or n.startswith(mod + '_')
        segs = [(start, size, name) for start, size, name, rec
                in self.linkmap.records
                if rec == 'D' and any(lo <= start < hi
                                      for lo, hi in regions)]
        for test in (lambda c: named(c[2]) and c[1] == s.size,
                     lambda c: c[2] == owner_seg and c[1] == s.size,
                     lambda c: named(c[2]),
                     lambda c: c[2] == owner_seg):
            cands = [c for c in segs if test(c)]
            if cands:
                start, size, name = cands[0]
                s.key = (start, LATE + len(self.all))
                s.why = '%s: data segment %s 0x%06X' % (why, name, start)
                return
        fall = C_WIRED if cls == C_SPECIAL else cls
        s.key = REGION_DATA_END_KEY[SAU][fall]
        s.why = '%s: no %s data segment; end of the %s data' \
                % (why, mod, CLASS_NAMES[fall])

    @staticmethod
    def _note(s):
        if s.map_syms:
            return s.map_syms[0][1]
        if s.follows is not None:
            return '%s (with %s)' % (s.name, Layout._note(s.follows))
        return s.name

    def _key_by_owner(self):
        todo = [s for s in self.sections + self.data + self.bss
                if s.key is None and not s.fixed]
        while todo:
            progress = False
            rest = []
            for s in todo:
                if s.refs and all(r.key is not None for r, _ in s.refs):
                    self._choose(s, [r for r, _ in s.refs])
                    progress = True
                else:
                    rest.append(s)
            todo = rest
            if progress:
                continue
            # a cycle, or references only from unkeyed sections: use the
            # owners known so far
            rest = []
            for s in todo:
                owners = [r for r, _ in s.refs if r.key is not None]
                if owners:
                    self._choose(s, owners)
                    progress = True
                else:
                    rest.append(s)
            todo = rest
            if progress:
                continue
            # nothing references these (or only each other): the object's
            # most resident placed section
            rest = []
            for s in todo:
                mates = [t for t in self.all if t.obj == s.obj
                         and t.key is not None and not t.fixed
                         and t.kind != 'block' and not t.nobits]
                if mates:
                    self._choose(s, mates)
                    s.why = 'unreferenced; ' + s.why
                    progress = True
                else:
                    rest.append(s)
            todo = rest
            if not progress:
                break
        for s in todo:
            if s.kind == 'code' or s.kind == 'rodata':
                s.key = RUNTIME_KEY[SAU]
            else:
                s.key = REGION_DATA_END_KEY[SAU][C_WIRED]
            s.why = 'no owner: wired'

    def _check_residency(self):
        """Nothing placed by owner may be less resident than a section
        that references it: a wired referencer needs it wired, one in a
        range wired on demand needs it wired or in the same range, an
        unwired one needs it outside the boot-only part.  (A cycle broken
        with the owners known so far, or a rule change, would otherwise
        put a callee of interrupt-level code in the paging file.)

        A section the map places (by a map symbol it defines, or a dpc
        section by its module's map segment) is where the image has it,
        and is not checked: the image itself has the wired
        PMAP_$PURIFIER_L call the boot-only pmap_$init_timers
        (`jsr 0x00e2f880' at 0xE13B22) once, before its loop, at boot."""
        def res(t):
            c = addr_class(t.key[0])
            return c, (special_pair(t.key[0]) if c == C_SPECIAL else None)

        def name(r):
            return CLASS_NAMES[r[0]] + \
                ('' if r[1] is None else ' range %d' % r[1])
        for s in self.all:
            if s.key is None or s.fixed or s.kind == 'block' \
                    or s.map_syms or s.map_segment or s.name in ANCHORS[SAU] \
                    or s.name in DATA_ANCHORS[SAU]:
                continue
            rs = res(s)
            if rs[0] == C_WIRED:
                continue
            for r, _ in s.refs:
                if r.key is None:
                    continue
                rr = res(r)
                if rr[0] == C_WIRED or (rr[0] == C_SPECIAL and rs != rr) \
                        or (rr[0] == C_UNWIRED and rs[0] == C_INIT):
                    self.errors.append(
                        '%s (%s) is less resident than its referencer %s '
                        '(%s)' % (s.label, name(rs), r.label, name(rr)))

    def nobits(self):
        """[(key, kind, item)] of the NOBITS part, in map order."""
        items = [(addr_key(b.addr), (0, 0), 'block', b)
                 for b in self.blocks if b.nobits]
        items += [(addr_key(w.addr), (0, 1), 'window', w)
                  for w in self.windows]
        items += [(addr_key(o.addr), (0, 2), 'overlay', o)
                  for o in self.overlays if o.nobits]
        items += [(s.key, (1, n), 'bss', s)
                  for n, s in enumerate(self.bss) if s.nobits]
        items.sort(key=lambda t: (t[0], t[1]))
        return items

    def cold_nobits(self):
        """The NOBITS part COLD maps (`.bss', below OS_PAGE_END)."""
        return [t for t in self.nobits() if t[0][0] < VM_WINDOWS_START[SAU]]

    def vm_nobits(self):
        """The NOBITS part in the VM tables' run-time windows
        (`.vm_tables', past OS_PAGE_END)."""
        return [t for t in self.nobits() if t[0][0] >= VM_WINDOWS_START[SAU]]

    def file_bss(self):
        """C bss sections that are zero bytes at the end of `.data' (none:
        every one is placed)."""
        return [s for s in self.bss if s.key is None]

    def _patterns(self):
        count = {}
        for s in self.all:
            count[s.name] = count.get(s.name, 0) + 1
        for s in self.all:
            if s.name != '.text' and count[s.name] == 1:
                s.pattern = 'KEEP(*("%s"))' % s.name
            else:
                s.pattern = 'KEEP(%s("%s"))' % (s.obj, s.name)

    def _check_blocks(self, objdump, objects):
        have = module_data_sections(objdump, objects)
        for b in self.blocks:
            if b.section not in have:
                self.errors.append('%s: no link input has section %s (is '
                                   'the site inside an #if?)'
                                   % (b.where, b.section))

    def ordered(self):
        """[(key, tiebreak, kind, item)] in link order."""
        items = []
        # tiebreaks are (rank, n) throughout so equal keys always compare:
        # a block first, then the section keyed there, then its followers
        # (a follower right after what it follows: rank 2 + its depth)
        for b in self.blocks:
            if not b.nobits:
                items.append((addr_key(b.addr), (0, 0, 0), 'block', b))
        for o in self.overlays:
            if not o.nobits:
                items.append((addr_key(o.addr), (0, 1, 0), 'overlay', o))
        items.append((RUNTIME_KEY[SAU], (1, 0, 0), 'runtime', None))
        for n, s in enumerate(self.sections + self.data + self.bss):
            if s.key is None or s.nobits:
                continue
            kind = 'section' if s.kind == 'code' else 'data'
            items.append((s.key, (2 if s.follows else 1, n, 0), kind, s))
        items.sort(key=lambda t: (t[0], t[1]))
        return items

    def catch_all(self):
        return [s for s in self.sections if s.key is None]

    def owned(self):
        """The sections keyed by owner, for the report."""
        return [s for s in self.sections + self.data + self.bss
                if s.why and s.key is not None]


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

def fragment(layout, map_path):
    lm = layout.linkmap
    out = []
    out.append('/*')
    out.append(' * layout.ld - GENERATED by tools/gen_layout_ld.py; do not '
               'edit.')
    out.append(' * INCLUDEd inside the `.text\' output section of kernel.ld.  '
               'Input sections')
    out.append(' * in the order of the SAU%d link map (%s),'
               % (SAU, os.path.basename(map_path)))
    out.append(' * each tagged with the map address that orders it; the '
               'addresses are')
    out.append(' * ordering keys, not placements.')
    out.append(' */')
    seg = None
    marks = section_aligns(lm, TEXT_MARKS[SAU], 0, IMAGE_BSS_START[SAU])
    for key, _, kind, item in layout.ordered():
        addr = key[0]
        cur = lm.segment_of(addr)
        if cur != seg:
            out.append('')
            out.append('    /* ---- %s ---- */' % (cur or '(no map segment)'))
            seg = cur
        align = item.align if kind in ('block', 'overlay', 'section',
                                       'data') else 1
        emit_marks(out, marks, addr, align or 1)
        if kind == 'block':
            if item.mark:
                out.append('    . = ALIGN(%d); %s = .;' % (item.align,
                                                          item.mark))
            stmt = item.pattern
            out.append('    %s%s/* %06X module data %s (%s) */'
                       % (stmt, pad(stmt, 0), addr, item.name, item.where))
        elif kind == 'overlay':
            emit_overlay(out, item)
        elif kind == 'runtime':
            out.append('    /* %06X run-time slot, wired, where M$ARITH ends: '
                       'no-owner and escaping code follows */' % addr)
        else:
            if item.why:
                note = item.why
            elif item.follows:
                note = 'with %s' % (item.follows.map_syms[0][1]
                                    if item.follows.map_syms
                                    else item.follows.name)
            elif item.map_syms:
                note = item.map_syms[0][1]
                if len(item.map_syms) > 1:
                    note += ' .. ' + item.map_syms[-1][1]
            else:
                note = 'anchor'
            if item.name in SCRIPT_PLACED:
                out.append('    /* %s: placed by kernel.ld (%06X %s) */'
                           % (item.name, addr, note))
                continue
            out.append('    %s%s/* %06X %s */'
                       % (item.pattern, pad(item.pattern, 0), addr, note))
            if item.size & 1:
                # The hand-written routines' sections are byte aligned
                # (they relied on being linked back to back) and a packed
                # C record may hold a pointer: keep every item that
                # follows an odd-sized one on a word.
                out.append('    . = ALIGN(2);')
    emit_marks(out, marks, None)
    out.append('')
    out.append('    /* ---- not in the SAU%d map: catch-all ---- */' % SAU)
    stmt = '%s = .;' % UNPLACED_MARK
    out.append('    %s%s/* no map position from here to RELOC */'
               % (stmt, pad(stmt, 0)))
    for s in layout.catch_all():
        out.append('    /* %s: %s */' % (s.label, s.why))
    out.append('    *(.text .text.*)')
    out.append('    KEEP(*(.moddata.*))')
    out.append('')
    return '\n'.join(out)


def emit_overlay(out, ov):
    """An overlay section's COMMON symbol, defined at its map position with
    the map segment's size (zeros in the file in `.text', NOBITS in
    `.bss')."""
    out.append('    . = ALIGN(%d);' % max(2, ov.align))
    stmt = '%s = .;' % ld_name(ov.name)
    out.append('    %s%s/* %06X overlay section %s, %s */'
               % (stmt, pad(stmt, 0), ov.addr, ov.name,
                  ('map size %X' % ov.map_size) if ov.map_size is not None
                  else 'map symbol; size %X from the COMMON' % ov.size))
    stmt = '. += 0x%X;' % ov.size
    out.append('    %s%s/* %s */' % (stmt, pad(stmt, 0), ov.where))


def emit_window(out, w):
    """A BSS_WINDOWS segment: its map symbols at the map's offsets from the
    first, then the segment's size."""
    base = ld_name(w.base)
    for a, n in w.syms:
        if a == w.addr and n == w.base:
            stmt = '%s = .;' % base
        elif a == w.addr:
            stmt = '%s = %s;' % (ld_name(n), base)
        else:
            stmt = '%s = %s + 0x%X;' % (ld_name(n), base, a - w.addr)
        out.append('    %s%s/* %06X map %s */' % (stmt, pad(stmt, 0), a, n))
    stmt = '. = %s + 0x%X;' % (base, w.size)
    out.append('    %s%s/* %06X the end of %s (window, no object) */'
               % (stmt, pad(stmt, 0), w.addr + w.size, w.where))


def data_fragment(layout, map_path):
    """build/sau2/layout_data.ld: INCLUDEd at the end of kernel.ld's `.data'
    output section.  The C bss objects that are zero bytes in the file."""
    out = ['/*',
           ' * layout_data.ld - GENERATED by tools/gen_layout_ld.py; do not '
           'edit.',
           ' * INCLUDEd at the end of the `.data\' output section of kernel.ld: '
           'the C bss',
           ' * objects (-fdata-sections) that the image did not have in its '
           'bss (no map',
           ' * symbol, or one outside 0x%06X..0x%06X), as zero bytes in the '
           'file.' % (IMAGE_BSS_START[SAU], IMAGE_BSS_END[SAU]),
           ' */']
    for s in layout.file_bss():
        if s.map_syms:
            note = '%06X %s' % (s.map_syms[0][0][0], s.map_syms[0][1])
        else:
            note = 'no map symbol'
        out.append('    %s%s/* %s */' % (s.pattern, pad(s.pattern, 0), note))
    out.append('    *(.bss)')
    out.append('    *(COMMON)')
    out.append('')
    return '\n'.join(out)


# The SAUs whose RFC image carries the fixup table at RELOC (the SAU2's,
# SAU3's, SAU5's, SAU8's; the SAU9's image ends at RELOC with no table).
RFC_FIXUP_TABLE = {2: True, 3: True, 5: True, 8: True, 9: False}
FIXUP_SLACK = 0    # entries beyond the inputs' count (every input is
                   # seen)


def bss_fragment(layout, map_path, nfixups):
    """build/sau2/layout_bss.ld: INCLUDEd inside kernel.ld's NOBITS `.bss'
    output section.  First the room for the fixup table, then the image's
    own bss, in map order; a block or object whose image address is page
    aligned starts a page here too."""
    out = ['/*',
           ' * layout_bss.ld - GENERATED by tools/gen_layout_ld.py; do not '
           'edit.',
           ' * INCLUDEd inside the NOBITS `.bss\' output section of kernel.ld: '
           'the zero-filled',
           ' * module data blocks and C bss objects at or past the image\'s '
           'RELOC 0x%06X,' % IMAGE_BSS_START[SAU],
           ' * in map order (%s).  Not in the file.  A page-aligned image '
           'address' % os.path.basename(map_path),
           ' * starts a page here too (stack guard pages, the MMAP and PTTX '
           'tables).',
           ' */',
           '',
           '    /* RELOC: room for the fixup table tools/gen_rfc_fixups.py '
           'appends here',
           '     * (count.w + %d longwords, one per R_68K_32 relocation of '
           'the inputs).' % nfixups,
           '     * The image let its table (43 KB) overlay ACL_$DATA, which '
           'ACL_$INIT',
           '     * zeroes; ours is larger than ACL_$DATA, so it gets RAM of '
           'its own and',
           '     * clobbers no block. */',
           '    /* %d entries of slack (no link input is hidden from this '
           'generator: libgcc' % FIXUP_SLACK,
           '     * is not linked). */',
           '    RFC_FIXUP_TABLE_END = . + 2 + 4 * %d;'
           % (max(nfixups, 1) + FIXUP_SLACK),
           '    . = RFC_FIXUP_TABLE_END;',
           '']
    if not RFC_FIXUP_TABLE[SAU]:
        # no fixup table: the image's bss starts at RELOC
        i = out.index('    /* RELOC: room for the fixup table tools/gen_rfc_fixups.py '
                      'appends here')
        out[i:] = ['    /* RELOC: the image has no fixup table (its COLD moves no '
                   'cells), so no', '     * room for one. */',
                   '    RFC_FIXUP_TABLE_END = .;', '']
    marks = section_aligns(layout.linkmap, BSS_MARKS[SAU],
                           IMAGE_BSS_START[SAU], VM_WINDOWS_START[SAU])
    for key, _, kind, item in layout.cold_nobits():
        addr = key[0]
        cur = emit_marks(out, marks, addr)
        if addr % PAGE == 0 and cur < PAGE:
            out.append('    . = ALIGN(0x%X);' % PAGE)
        if kind == 'block':
            if item.mark:
                out.append('    . = ALIGN(%d); %s = .;' % (item.align,
                                                          item.mark))
            stmt = item.pattern
            out.append('    %s%s/* %06X module data %s (%s) */'
                       % (stmt, pad(stmt, 0), addr, item.name, item.where))
        elif kind == 'window':
            emit_window(out, item)
        elif kind == 'overlay':
            emit_overlay(out, item)
        else:
            if item.map_syms:
                note = item.map_syms[0][1]
                if len(item.map_syms) > 1:
                    note += ' .. ' + item.map_syms[-1][1]
            else:
                note = 'anchor ' + item.name
            out.append('    %s%s/* %06X %s */'
                       % (item.pattern, pad(item.pattern, 0), addr, note))
    emit_marks(out, marks, None)
    out.append('')
    # ld gives an input section to the first statement that matches it, and
    # `.bss' precedes `.vm_tables' in kernel.ld: keep the catch-all off the
    # objects owning a window object so layout_vm.ld gets them.  (The map
    # key alone cannot do it: `.vm_tables' starts at OS_PAGE_END, which is
    # only known once `.bss' is laid out, so it cannot come first in the
    # script.  If the exclusion ever misses, the object lands in `.bss'
    # below OS_PAGE_END and kernel.ld's ASSERTs on the windows' order and
    # offsets fail the link, so a miss is never silent.)
    # (A module data block there would need its object found the same way;
    # there is none, and one is refused rather than silently caught.)
    vm_blocks = [item.name for _, _, kind, item in layout.vm_nobits()
                 if kind == 'block']
    if vm_blocks:
        fail(['module data block(s) %s keyed in the VM tables\' run-time '
              'windows (0x%06X..): not supported by layout_vm.ld'
              % (', '.join(vm_blocks), VM_WINDOWS_START[SAU])])
    vm_objs = sorted({item.obj for _, _, kind, item in layout.vm_nobits()
                      if kind != 'overlay'})
    out.append('    /* not listed above (none expected)%s */'
               % ('; not from the objects holding the VM-table windows'
                  if vm_objs else ''))
    if vm_objs:
        out.append('    *(EXCLUDE_FILE(%s) .bss.*)'
                   % ' '.join('*' + o.split('build/sau%d/' % SAU, 1)[-1]
                              for o in vm_objs))
    else:
        out.append('    *(.bss.*)')
    out.append('')
    return '\n'.join(out)


def vm_fragment(layout, map_path):
    """build/sau2/layout_vm.ld: INCLUDEd inside kernel.ld's NOBITS
    `.vm_tables', which starts at OS_PAGE_END.  The map's VM_TABLES from
    AREA_$RPMAP_CACHE up, at the map's offsets from it."""
    lm = layout.linkmap
    marks = []
    for name in VM_WINDOW_MARKS[SAU]:
        if name not in lm.symbols:
            fail(['the map has no %s (VM_WINDOW_MARKS)' % name])
        marks.append((lm.symbols[name][0], name))
    base_addr, base = marks[0]
    if base_addr != VM_WINDOWS_START[SAU]:
        fail(['the map\'s %s is 0x%06X, not VM_WINDOWS_START 0x%06X'
              % (base, base_addr, VM_WINDOWS_START[SAU])])
    if marks[-1][0] > IMAGE_BSS_END[SAU]:
        fail(['%s 0x%06X is past IMAGE_BSS_END' % marks[-1][::-1]])
    out = ['/*',
           ' * layout_vm.ld - GENERATED by tools/gen_layout_ld.py; do not '
           'edit.',
           ' * INCLUDEd inside the NOBITS `.vm_tables\' output section of '
           'kernel.ld, which',
           ' * starts at OS_PAGE_END: the run-time windows of the map\'s '
           'VM_TABLES (%s),' % os.path.basename(map_path),
           ' * in map order at the map\'s offsets from %s.  COLD maps none '
           'of it;' % base,
           ' * the kernel installs fresh pages there.',
           ' */',
           '']
    rows = [(a, 0, 'mark', n) for a, n in marks]
    rows += [(key[0], 1, kind, item) for key, _, kind, item
             in layout.vm_nobits()]
    rows.sort(key=lambda r: (r[0], r[1]))
    here = base_addr
    for addr, _, kind, item in rows:
        if base == 'OS_PAGE_END':
            # the base is kernel.ld's (an absolute symbol, which ld would
            # take as an offset in the section): step from the last row
            if addr != here:
                stmt = '. += 0x%X;' % (addr - here)
                out.append('    %s%s/* %06X */' % (stmt, pad(stmt, 0), addr))
            here = addr
            if kind == 'overlay':
                here += item.size
        elif addr != base_addr:
            stmt = '. = %s + 0x%X;' % (base, addr - base_addr)
            out.append('    %s%s/* %06X */' % (stmt, pad(stmt, 0), addr))
        if kind == 'mark':
            if item == 'OS_PAGE_END':
                # the section's start, which kernel.ld defines
                out.append('    /* %06X map OS_PAGE_END: the start of '
                           '.vm_tables */' % addr)
                continue
            stmt = '%s = .;' % item
            out.append('    %s%s/* %06X map %s */' % (stmt, pad(stmt, 0),
                                                       addr, item))
        elif kind == 'overlay':
            emit_overlay(out, item)
        elif kind == 'block':
            stmt = item.pattern
            out.append('    %s%s/* %06X module data %s (%s) */'
                       % (stmt, pad(stmt, 0), addr, item.name, item.where))
        else:
            note = item.map_syms[0][1] if item.map_syms else \
                'anchor ' + item.name
            out.append('    %s%s/* %06X %s */'
                       % (item.pattern, pad(item.pattern, 0), addr, note))
    out.append('')
    return '\n'.join(out)


# Output sections kernel.ld discards: their relocations never reach the link.
DISCARDED_PREFIXES = ('.comment', '.note', '.eh_frame', '.debug')


def count_fixups(objects):
    """The number of R_68K_32 relocations in the allocated, kept sections
    of the link inputs: the entries tools/gen_rfc_fixups.py will write
    (ld resolves every one of them into a 32-bit address cell)."""
    n = 0
    for obj in objects:
        elf = rfc_elf.Elf(obj)
        for sec, _, typ, _, _ in elf.relocations():
            if typ == rfc_elf.R_68K_32 and \
                    not sec.name.startswith(DISCARDED_PREFIXES):
                n += 1
    return n


def write_if_changed(path, text):
    try:
        with open(path) as f:
            if f.read() == text:
                # unchanged: refresh the timestamp so make is satisfied
                os.utime(path)
                return
    except FileNotFoundError:
        pass
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    with open(path, 'w') as f:
        f.write(text)


def pad(text, extra):
    width = 56
    n = len(text) + 4 + extra
    return ' ' * max(1, width - n)


# ---------------------------------------------------------------------------
# The order check
# ---------------------------------------------------------------------------

def elf_symbols(nm, elf):
    out = subprocess.run([nm, '--defined-only', elf], check=True,
                         capture_output=True, text=True).stdout
    # Absolute symbols (`a'/`A': the hand-written files' `.set' equates
    # for image addresses) are not linked objects; a global definition
    # wins over file-static ones of the same name.
    found = {}
    for line in out.splitlines():
        f = line.split()
        if len(f) == 3 and f[1] not in 'aA':
            found.setdefault(f[2], []).append((f[1], int(f[0], 16)))
    syms = {}
    for name, defs in found.items():
        glob = [a for t, a in defs if t.isupper()]
        syms[name] = glob if glob else [a for t, a in defs]
    return syms


def item_start(kind, item, syms):
    """The linked address of an item's first byte, or None: a block's
    mark, an overlay's or a window's symbol, a section's first symbol that
    the ELF defines once, less its offset in the section."""
    if kind == 'block':
        names = [item.mark]
    elif kind == 'overlay':
        names = [item.name]
    elif kind == 'window':
        names = [item.base]
    else:
        for name in item.symbols:
            addrs = syms.get(name)
            if addrs and len(addrs) == 1:
                return addrs[0] - item.offsets[name]
        return None
    addrs = syms.get(names[0])
    return addrs[0] if addrs else None


def page_checks(layout, syms):
    """Every numbered map section that starts a page (page_sections)
    starts one here: the first item placed at or past its map address is
    on a page.  -> (errors, number of sections with an item placed at or
    past them)"""
    errors = []
    items = [t for t in layout.ordered() + layout.nobits()
             if t[2] != 'runtime' and getattr(t[3], 'name', None)
             not in SCRIPT_PLACED]
    keys = [t[0][0] for t in items]
    checked = 0
    for addr, secs in page_sections(layout.linkmap):
        i = bisect.bisect_left(keys, addr)
        if i == len(items):
            continue    # nothing placed from here on
        key, _, kind, item = items[i]
        checked += 1
        start = item_start(kind, item, syms)
        what = getattr(item, 'label', None) or item.name
        if start is None:
            errors.append('map %s starts a page at 0x%06X; the first item '
                          'placed there, %s, has no symbol to find it by'
                          % (section_names(secs), addr, what))
        elif start % PAGE:
            errors.append('map %s starts a page at 0x%06X, but the first '
                          'item placed there, %s (map 0x%06X), is linked at '
                          '0x%08X, not on a page'
                          % (section_names(secs), addr, what, key[0], start))
    return errors, checked


def check_elf(layout, elf, nm):
    lm = layout.linkmap
    syms = elf_symbols(nm, elf)
    errors = []
    rows = []   # (map key, name, elf address)
    # the loaded stream, then the NOBITS part (the image's bss), which is
    # in map order too (IMAGE_BSS_START): one check covers both
    for key, _, kind, item in layout.ordered() + layout.nobits():
        if kind == 'block':
            addrs = syms.get(item.mark or item.name)
            if not addrs:
                errors.append('%s: block %s is not in %s'
                              % (item.where, item.name, elf))
                continue
            rows.append((key, item.name, addrs[0], 'block'))
            continue
        if kind == 'runtime':
            continue
        if kind == 'overlay':
            addrs = syms.get(item.name)
            if not addrs:
                errors.append('%s is not in %s' % (item.where, elf))
                continue
            rows.append((key, item.name, addrs[0], 'overlay'))
            continue
        if kind == 'window':
            base = syms.get(item.base)
            for a, name in item.syms:
                addrs = syms.get(name)
                if not addrs or not base:
                    errors.append('%s: %s is not in %s'
                                  % (item.where, name, elf))
                    continue
                if addrs[0] - base[0] != a - item.addr:
                    errors.append('%s: %s is at %s + 0x%X, the map has '
                                  '+0x%X' % (item.where, name, item.base,
                                             addrs[0] - base[0],
                                             a - item.addr))
                rows.append((lm.key(name), name, addrs[0], 'window'))
            continue
        if not item.map_syms and (item.name in ANCHORS[SAU]
                                  or item.name in DATA_ANCHORS[SAU]):
            # An anchored section defines no map symbol; check it by its
            # first symbol (SVC_$TRAP8_TABLE, SMD_DISPLAY_INFO) at the
            # anchor's key, so a table drifting away from the routine that
            # reaches it PC-relatively is an inversion like any other.
            if not item.symbols:
                errors.append('%s (anchor) defines no symbol to check'
                              % item.label)
                continue
            name = item.symbols[0]
            addrs = syms.get(name)
            if not addrs:
                errors.append('%s defines %s but %s does not'
                              % (item.label, name, elf))
                continue
            rows.append((key, name, addrs[0], 'anchor'))
            continue
        for mkey, name in item.map_syms:
            addrs = syms.get(name)
            if not addrs:
                errors.append('%s defines %s but %s does not'
                              % (item.label, name, elf))
                continue
            if len(addrs) > 1:
                errors.append('%s is defined %d times in %s'
                              % (name, len(addrs), elf))
            rows.append((mkey, name, addrs[0],
                         'bss' if kind == 'bss' else 'symbol'))
    # The marks (TEXT_MARKS, BSS_MARKS, the VM-table windows') are in map
    # order with the rest.
    for name in [n for _, n, _ in TEXT_MARKS[SAU] + BSS_MARKS[SAU]] + \
            VM_WINDOW_MARKS[SAU]:
        addrs = syms.get(name)
        if addrs and name in lm.symbols:
            rows.append((lm.key(name), name, addrs[0], 'mark'))
    # The map's fixed VAs (the trap page, the PTT and PROT windows, the low
    # region OS_LOW .. OS_LOW_END, the crash record page, the I/O pages from
    # IODEFS up): absolute symbols of the SAU's script and arch/m68k/<sau>/
    # iodefs.s, or the crash record's at OS_BEGIN; each must have the map's
    # value.
    linked_syms = rfc_elf.Elf(elf)
    nfixed = 0
    for name, (a, _) in sorted(lm.symbols.items()):
        if not (a < FIXED_LOW_END[SAU] or a >= FIXED_IO_START[SAU]):
            continue
        if any(lo <= a < hi for lo, hi in FIXED_EXEMPT[SAU]):
            continue
        v = linked_syms.symbol(name)
        if v is None:
            continue
        nfixed += 1
        if v != a:
            errors.append('%s is 0x%08X in %s; the map\'s fixed VA is '
                          '0x%06X' % (name, v, elf, a))
    rows.sort(key=lambda r: r[0])
    inversions = 0
    first = None
    for a, b in zip(rows, rows[1:]):
        if b[2] < a[2]:
            inversions += 1
            if first is None:
                first = (a, b)
    nsym = sum(1 for r in rows if r[3] == 'symbol')
    nblk = sum(1 for r in rows if r[3] == 'block')
    nanc = sum(1 for r in rows if r[3] == 'anchor')
    nbss = sum(1 for r in rows if r[3] == 'bss')
    nwin = sum(1 for r in rows if r[3] == 'window')
    nov = sum(1 for r in rows if r[3] == 'overlay')
    nmark = sum(1 for r in rows if r[3] == 'mark')
    nnob = sum(1 for t in layout.nobits() if t[2] == 'block')
    print('gen_layout_ld: %d map symbols, %d anchored section(s) and %d '
          'module data block(s) placed in map order (of %d map symbols; the '
          'rest are not translated or live in .data/.bss)'
          % (nsym, nanc, nblk, len(lm.symbols)))
    print('gen_layout_ld: of those, the image\'s bss (past RELOC 0x%06X, '
          'NOBITS): %d block(s) and %d C bss map symbol(s); %d C bss '
          'object(s) are file zeros'
          % (IMAGE_BSS_START[SAU], nnob, nbss, len(layout.file_bss())))
    print('gen_layout_ld: %d mark(s), %d window symbol(s) of %d BSS_WINDOWS '
          'segment(s) and %d overlay section(s) (COMMON) in map order; %d '
          'fixed-VA map symbol(s) at their map values'
          % (nmark, nwin, len(layout.windows), nov, nfixed))
    catch = layout.catch_all()
    nfun = sum(len(s.symbols) for s in catch)
    print('gen_layout_ld: %d code section(s) with %d symbol(s) in the '
          'catch-all:' % (len(catch), nfun))
    for s in catch:
        print('    %s: %s' % (s.label, s.why))
    # and nothing the generator did not see (an input section of a kind it
    # does not read) fell through to kernel.ld's own catch-alls: the end of
    # `.text' is OS_LINK_UNPLACED and `.rodata' / `.data' are empty
    linked = rfc_elf.Elf(elf)
    text = linked.section('.text')
    unplaced = syms.get(UNPLACED_MARK)
    if text and unplaced and unplaced[0] != text.addr + text.size:
        errors.append('%d byte(s) of .text after %s: input sections the '
                      'generator did not place'
                      % (text.addr + text.size - unplaced[0], UNPLACED_MARK))
    for name in ('.rodata', '.data'):
        sec = linked.section(name)
        if sec and sec.size:
            errors.append('%s is 0x%X bytes: input sections the generator '
                          'did not place' % (name, sec.size))
    if catch or layout.file_bss():
        errors.append('%d section(s) left to the catch-all: every input '
                      'section needs a map position, an anchor or an owner'
                      % (len(catch) + len(layout.file_bss())))
    # what the owner rule placed, by the residency of its position
    owned = {}
    for s in layout.owned():
        cls = 'nobits' if s.nobits else CLASS_NAMES[addr_class(s.key[0])]
        n, size = owned.get(cls, (0, 0))
        owned[cls] = (n + 1, size + s.size)
    print('gen_layout_ld: placed by owner: %s'
          % ', '.join('%s %d section(s) %d bytes' % (c, n, size)
                      for c, (n, size) in sorted(owned.items())))
    print('gen_layout_ld: %d order inversion(s)' % inversions)
    page_errors, npage = page_checks(layout, syms)
    print('gen_layout_ld: %d numbered map section(s) that start a page: '
          '%d start one here too' % (npage, npage - len(page_errors)))
    errors += page_errors
    if first:
        (ka, na, ea, _), (kb, nb, eb, _) = first
        errors.append('first inversion: %s (map 0x%06X) is linked at 0x%08X '
                      'but %s (map 0x%06X) at 0x%08X'
                      % (na, ka[0], ea, nb, kb[0], eb))
    return errors


def table_checks(linkmap):
    """The SAU's tables against its map: the map is the evidence for every
    address, so a table entry the map contradicts (the wrong SAU's map, a
    typo) stops the run before anything is laid out."""
    errors = []

    def at(name, addr, what):
        got = linkmap.symbols.get(name, (None,))[0]
        if got != addr:
            errors.append('%s: the map (--sau %d) has %s at %s, the table '
                          '0x%06X'
                          % (what, SAU, name, 'nothing' if got is None
                             else '0x%06X' % got, addr))
    at('RELOC', IMAGE_BSS_START[SAU], 'IMAGE_BSS_START')
    at('IODEFS_GUARD', IMAGE_BSS_END[SAU], 'IMAGE_BSS_END')
    at('IODEFS', FIXED_IO_START[SAU], 'FIXED_IO_START')
    at(VM_WINDOW_MARKS[SAU][0], VM_WINDOWS_START[SAU], 'VM_WINDOWS_START')
    at('OS_BEGIN', RFC_LOAD_ADDR[SAU], 'RFC_LOAD_ADDR')
    # a mark that is a map symbol is at the map's address (the others are
    # named after map segments: OS_PROC_UNWIRED, RING_PROC_START, ...)
    for addr, name, _ in TEXT_MARKS[SAU] + BSS_MARKS[SAU]:
        if name in linkmap.symbols:
            at(name, addr + MARK_DELTAS.get(SAU, {}).get(name, 0),
               'TEXT_MARKS/BSS_MARKS')
    for marks in (TEXT_MARKS[SAU], BSS_MARKS[SAU]):
        addrs = [a for a, _, _ in marks]
        if addrs != sorted(addrs):
            errors.append('TEXT_MARKS/BSS_MARKS[%d] are not in map order'
                          % SAU)
    return errors


# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--sau', type=int, default=2, choices=SAUS,
                    help='the SAU whose map this is and whose address '
                    'tables to use (default 2)')
    ap.add_argument('--map', required=True,
                    help='the link map of that SAU\'s image')
    ap.add_argument('-o', '--output', help='fragment to write')
    ap.add_argument('--check-only', action='store_true',
                    help='run the checks, write nothing')
    ap.add_argument('--check-elf', metavar='ELF',
                    help='verify the link order of a linked ELF')
    ap.add_argument('--objdump', default='m68k-elf-objdump')
    ap.add_argument('--nm', default='m68k-elf-nm')
    ap.add_argument('objects', nargs='*')
    args = ap.parse_args()
    global SAU
    SAU = args.sau

    if not os.path.exists(args.map):
        fail(['link map %s not found (set SAU2_MAP, or SAU_MAP for another '
              'SAU)' % args.map])
    linkmap = LinkMap(args.map)
    errors = table_checks(linkmap)
    if errors:
        fail(errors)

    blocks, errors = dpc_blocks(linkmap, args.objdump, args.objects)
    if errors:
        fail(errors)
    errors = block_checks(blocks, linkmap)
    layout = Layout(linkmap, blocks, args.objects, args.objdump)
    errors += layout.errors
    if errors:
        fail(errors)

    if args.check_elf:
        if not os.path.exists(args.check_elf):
            fail(['%s not found (did the scratch link fail?)'
                  % args.check_elf])
        errors = check_elf(layout, args.check_elf, args.nm)
        if errors:
            fail(errors)
        return

    if args.check_only:
        nob = len(layout.nobits())
        print('gen_layout_ld: %d section(s) placed, %d block(s), '
              '%d in the catch-all, %d NOBITS item(s), %d C bss object(s) '
              'as file zeros; checks passed'
              % (sum(1 for t in layout.ordered() if t[2] == 'section'),
                 len(blocks), len(layout.catch_all()), nob,
                 len(layout.file_bss())))
        return
    if not args.output:
        fail(['-o, --check-only or --check-elf is required'])

    out_dir = os.path.dirname(args.output) or '.'
    write_if_changed(args.output, fragment(layout, args.map))
    write_if_changed(os.path.join(out_dir, 'layout_data.ld'),
                     data_fragment(layout, args.map))
    write_if_changed(os.path.join(out_dir, 'layout_bss.ld'),
                     bss_fragment(layout, args.map,
                                  count_fixups(args.objects)))
    write_if_changed(os.path.join(out_dir, 'layout_vm.ld'),
                     vm_fragment(layout, args.map))


if __name__ == '__main__':
    main()
