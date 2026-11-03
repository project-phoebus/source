{ os/cold.pas - the OS_COLD module: the kernel's first translation tables,
  built before the MMU is on.

  Image addresses:
    sau9  0x04002FFC  OS_COLD data (COLD, 0x6C bytes: the boot map)
    sau9  0x04003068  OS_COLD code (COLD_PROC, 0x568 bytes)

  One compilation unit in the map's COLD_PROC (code) and COLD (data)
  sections, which COLD (cold/sau9/cold_start.s) runs from where the
  loader put them, physical = VA, MMU off: the heading names the two.
  COLD calls OS_$COLD_START once, with the boot record, the memory size
  and flags it found and a status; OS_$COLD_START clears the tables,
  marks the present memory in MMAP, maps each entry of the boot map, and
  points the root table's entries at the segment tables.  The routines
  reach the kernel's tables by the physical address of their VA
  (cold_phys): the kernel loaded at physical 0x4004400 for OS_PROC, the
  DUMP page copied to 0x4001400.

  The data block (COLD), the boot map, 9 entries of 12 bytes: the
  physical address, the VA, the page count (0: the kernel's, OS_PROC ..
  OS_PAGE_END) and the flags (os_cold_flags_t):

    +0x00  OS_BEGIN       0x4000000   4 pages   the crash record's
    +0x0C  DUMP           0x4001400   2         the DUMP page
    +0x18  TRAP_PAGE      0x4002000   1         the vector page
    +0x24  PROM + 0x400   0x400       0x7F      the PROM
    +0x30  COLD           0x4002400   6         COLD itself
    +0x3C  OS_PROC        0x4004400   0         the kernel
    +0x48  RARS           0x4001C00   1         the root tables' page
    +0x54  CPU            0x20000     4         the CPU and utility pages
    +0x60  DISP1_MEM      0x1000000   0x100     the display memory

  With the part cold_proc_tables (base/config.ins.pas): only the SAU7's
  and the SAU9's maps have OS_COLD (the SAU7's another form, not
  written); elsewhere the module is empty.

  The routines live in one fragment file each (os/<name>.pas), included
  below in image order.  Check: tools/pascal_check.sh.
}
module os_cold, cold_proc, cold;

%include 'base/base.ins.pas';
%if cold_proc_tables %then
%include 'mmu/mmu.ins.pas';                   { MMU_$RARS_PHADDR,
                                                MMU_$OS_PMAPS_PHADDR }

const
  { "cold start error" (OS / startup/shutdown, stcode.db.10.2) }
  status_$cold_start_error = 16#001B0007;

  { Where the loader and COLD put the kernel and the DUMP page, and the
    root table's page (RARS's physical home). }
  os_cold_kernel_pa = 16#04004400;        { OS_PROC as loaded (file 0x2000) }
  os_cold_dump_pa = 16#04001400;          { DUMP's copy }
  os_cold_rars_pa = 16#04001C00;          { the root table }

  { The pageable memory's first page (MMAP's first entry). }
  os_cold_first_ppn = 16#10000;

  { Segments: global A's two tables at root indices 237 and 238; the
    global segments (global B) from root index 240 (VA 16#3C000000),
    segment 30720; COLD's own segment is 2048 (VA 16#04000000). }
  os_cold_global_a_root = 237;
  os_cold_global_root = 240;
  os_cold_global_seg = 30720;
  os_cold_cold_seg = 2048;

type
  { A boot map entry's flags, a word. }
  os_cold_flags_t = packed record
    valid: boolean;                       { bit 15: map it }
    write: boolean;                       { bit 14: writable (else the
                                            segment is write protected) }
    seg_bit_1: boolean;                   { bit 13 } { copied into the }
    seg_bit_0: boolean;                   { bit 12 } { descriptor's low bits }
    mmap_bit_7: boolean;                  { bit 11: each page's MMAP
                                            entry present }
    mmap_bit_6: boolean;                  { bit 10: and pageable }
    cacheable: boolean;                   { bit 9: else cache inhibited }
    unused: 0..511;                       { bits 8..0 }
  end;

  os_cold_map_entry_t = record
    pa: linteger;                         { 0x00 }
    case integer of                       { 0x04: the VA }
      1: (va: univ_ptr;                   {   a kernel object's }
          count: integer;                 { 0x08 }
          flags: os_cold_flags_t);        { 0x0A }
      2: (va_io: integer32);              {   an I/O address }
  end;

  { The boot record's start, COLD's cold_boot_params: the PROM's D1 and
    D2, the boot flags D2's low word (a word set: the SAU9 image masks
    and compares it as a word). }
  os_cold_boot_params_t = record
    device: integer32;                    { 0x00 }
    unused_04: integer;                   { 0x04 }
    flags: set of 0..15;                  { 0x06 }
  end;

  { A virtual address and its fields: the root table's index, the
    segment (and its index in its table of 128), the page in the
    segment.  The SAU9 image reads the fields as bit fields. }
  os_cold_va_t = packed record
    case integer of
      1: (all: linteger);                 { 0x00 }
      2: (ptr: univ_ptr);                 { 0x00 }
      3: (bits_31_30: 0..3;               { bits 31..30 }
          segno: 0..16#7FFF;              { bits 29..15 }
          page: 0..31;                    { bits 14..10 }
          offset: 0..1023);               { bits 9..0 }
      4: (unused_31_30: 0..3;             { bits 31..30 }
          root: 0..255;                   { bits 29..22 }
          table_seg: 0..127);             { bits 21..15 }
  end;

  { A segment's descriptor, an MC68030 long-format table descriptor (8
    bytes): the limit, the reserved ones, supervisor only, write protect
    and the type in the first longword; the page map's physical address
    in the second, its low four bits (unused by the MMU) a copy of the
    boot map entry's flags. }
  os_cold_sd_t = packed record
    case integer of
      1: (lu: boolean;                    { bit 31 }
          limit: 0..16#7FFF;              { bits 30..16 }
          bits_15_10: 0..63;              { bits 15..10 }
          sg: boolean;                    { bit 9 }
          s: boolean;                     { bit 8 }
          bits_7_3: 0..31;                { bits 7..3 }
          wp: boolean;                    { bit 2 }
          dt: 0..3;                       { bits 1..0 }
          table: integer32);              { 0x04 }
      2: (all: integer32;                 { 0x00 }
          table_hi: 0..16#FFFFFFF;        { 0x04 bits 31..4 }
          valid: boolean;                 { bit 3 }
          write: boolean;                 { bit 2 }
          seg_bit_1: boolean;             { bit 1 }
          seg_bit_0: boolean);            { bit 0 }
  end;

  { A page's descriptor, an MC68030 short-format page descriptor: the
    frame, cache inhibit, write protect, and the type's low bit
    (resident); the low word is odd while it is resident. }
  os_cold_pd_t = packed record
    case integer of
      1: (frame: 0..16#3FFFFF;            { bits 31..10 }
          bits_9_7: 0..7;                 { bits 9..7 }
          ci: boolean;                    { bit 6 }
          bits_5_3: 0..7;                 { bits 5..3 }
          wp: boolean;                    { bit 2 }
          bit_1: boolean;                 { bit 1 }
          resident: boolean);             { bit 0 }
      2: (unused_hi: integer;             { 0x00 }
          low: integer);                  { 0x02 }
  end;

  { A segment's page map, 32 descriptors. }
  os_cold_pmap_t = array[0..31] of os_cold_pd_t;

  { SMAPS: the segment descriptors of global A (root entries 237 and
    238), of the global segments (240..255) and of ASID 0's private
    segments (from segment 0). }
  os_cold_smaps_t = record
    global_a: array[0..255] of os_cold_sd_t;      { 0x0000 }
    global_b: array[0..2047] of os_cold_sd_t;     { 0x0800 }
    private_a: array[0..30335] of os_cold_sd_t;   { 0x4800 }
  end;

  { A page's MMAP entry, 16 bytes; OS_COLD sets its first byte's two
    marks, which MMAP_$INIT reads: present (bit 7) and pageable (bit
    6). }
  os_cold_mmape_t = packed record
    present: boolean;                     { 0x00 bit 7 }
    pageable: boolean;                    { 0x00 bit 6 }
    bits_5_0: 0..63;                      { 0x00 bits 5..0 }
    unused_01: char;                      { 0x01 }
    unused_02: array[1..14] of char;      { 0x02 }
  end;

  { A table cleared by longwords (MMAP's 16#100000 bytes the largest,
    and one longword more). }
  os_cold_table_t = array[0..262144] of integer32;

  { A root table entry, an MC68030 short-format table descriptor: the
    table's address, and the type in the low word's members 1..0. }
  os_cold_root_t = record
    case integer of
      1: (all: integer32);                { 0x00 }
      2: (unused_hi: integer;             { 0x00 }
          flags: set of 0..15);           { 0x02 }
  end;

  os_cold_table_ptr_t = ^os_cold_table_t;
  os_cold_sd_ptr_t = ^os_cold_sd_t;
  os_cold_pmap_ptr_t = ^os_cold_pmap_t;
  os_cold_mmape_ptr_t = ^os_cold_mmape_t;
  os_cold_mmap_ptr_t = ^array[16#10000..16#1FFFF] of os_cold_mmape_t;
  os_cold_root_ptr_t = ^os_cold_root_t;
  os_cold_lp_t = ^integer32;

var
  { The kernel's marks and tables (map symbols; only their addresses are
    used). }
  os_begin, dump, trap_page, cold, os_proc, rars, cpu: extern char;
  disp1_mem: extern char;
  os_page_end, os_data_wired, os_init_start, os_init_data_start: extern char;
  os_proc_unwired, os_proc_end: extern char;
  mmap, os_pmap_end: extern char;
  { OS_PMAPS's page maps of the global segments, by segment number;
    OS_PMAP_SPECIAL's, COLD's segment's; SMAPS's segment descriptors. }
  os_pmaps: extern array[30720..32767] of os_cold_pmap_t;
  os_pmap_special: extern os_cold_pmap_t;
  smaps: extern os_cold_smaps_t;
  { The cells that keep the tables' physical addresses (DUMP's,
    dump/sau9/dump.s; MMU_ASM's are mmu/mmu.ins.pas's). }
  dump_$smap_phaddr, dump_$rars_phaddr: extern integer32;

  { The boot map (the module's data block). }
  os_cold_map: array[1..9] of os_cold_map_entry_t := [
    [pa := 16#04000000, va := addr(os_begin), count := 4,
     flags := [valid := true, write := true, seg_bit_1 := true,
               seg_bit_0 := true, mmap_bit_7 := true,
               cacheable := true]],
    [pa := 16#04001400, va := addr(dump), count := 2,
     flags := [valid := true, write := true, seg_bit_1 := true,
               seg_bit_0 := true, mmap_bit_7 := true,
               cacheable := true]],
    [pa := 16#04002000, va := addr(trap_page), count := 1,
     flags := [valid := true, write := true, seg_bit_1 := true,
               seg_bit_0 := true, mmap_bit_7 := true,
               cacheable := true]],
    [pa := 16#00000400, va_io := 16#3FFE0400,       { PROM + 16#400 }
     count := 127,
     flags := [valid := true, seg_bit_1 := true, seg_bit_0 := true,
               mmap_bit_7 := true, cacheable := true]],
    [pa := 16#04002400, va := addr(cold), count := 6,
     flags := [valid := true, write := true, seg_bit_1 := true,
               seg_bit_0 := true, mmap_bit_6 := true, cacheable := true]],
    [pa := os_cold_kernel_pa, va := addr(os_proc), count := 0,
     flags := [valid := true, write := true, seg_bit_1 := true,
               seg_bit_0 := true, mmap_bit_7 := true,
               cacheable := true]],
    [pa := os_cold_rars_pa, va := addr(rars), count := 1,
     flags := [valid := true, write := true, seg_bit_1 := true,
               mmap_bit_7 := true, cacheable := true]],
    [pa := 16#00020000, va := addr(cpu), count := 4,
     flags := [valid := true, write := true, seg_bit_1 := true]],
    [pa := 16#01000000, va := addr(disp1_mem), count := 256,
     flags := [valid := true, write := true, seg_bit_1 := true,
               cacheable := true]]];

{ The global routine this module defines (ref 7.3.4, Method 2). }
define
  os_$cold_start;

{ ---- COLD_PROC ---- }
%include 'os/cold_clear.pas';               { cold_clear (module-local) }
%include 'os/cold_phys.pas';                { cold_phys (module-local) }
%include 'os/cold_page_round.pas';          { cold_page_round (module-local) }
%include 'os/cold_set_root.pas';            { cold_set_root (module-local) }
%include 'os/cold_start.pas';               { OS_$COLD_START }
%endif
