{ mmu/mmu_page.ins.pas - the MMU page and the page frame table, for the
  Domain Pascal tree.

  The MMU page's registers and the PFT as compiled code reads them:
  mmu/mmu.ins.pas includes this file, and so does a unit that declares
  the MMU_$ headings of its own MMU instead of including that file
  (os/os.pas without `pft_mmu').
}

{ The MMU page of the SAU2 I/O map as PARITY_$CHK reads it, and the page
  frame table: the map's IODEFS symbols MMU (0xFFB400 on the SAU2) and
  PFT (0xFFB800), absolute symbols without `$', so extern variables
  here.  The types hold only what PARITY reads and writes.  The error
  word's stores are read-modify-write forms the `device' attribute
  forbids (ref 3.15.3), so the page is not `[device]'. }

type
  { The memory error word, at +0x6 of the MMU page, and the low word of
    the SAU2 error longword: a packed record of 16 bits (ref 3.10.7;
    fields from the most significant bit) with three variants.
    - 1, the SAU1 layout: the page frame in bits 15..4, and the flags
      DMA (8), byte lower (4) and byte upper (2).
    - 2, the SAU2 layout: the byte lanes in bits 11..8, and the DMA
      flags upper (16#20) and lower (16#10).
    - 3, the whole word. }
  mmu_$mem_err_word_t = packed record
    case integer of
      1: (sau1_ppn: 0..4095;              { bits 15..4 }
          sau1_dma: boolean;              { bit 3 }
          sau1_byte_lower: boolean;       { bit 2 }
          sau1_byte_upper: boolean;       { bit 1 }
          sau1_bit_0: boolean);           { bit 0 }
      2: (sau2_bits_15_12: 0..15;         { bits 15..12 }
          sau2_lanes: 0..15;              { bits 11..8 }
          sau2_bits_7_6: 0..3;            { bits 7..6 }
          sau2_dma_upper: boolean;        { bit 5 }
          sau2_dma_lower: boolean;        { bit 4 }
          sau2_bits_3_0: 0..15);          { bits 3..0 }
      3: (all: pinteger);
  end;

  { The SAU6's system revision word, +0x4 of the MMU page (the word
    MMU_$SET_SYSREV copies into MMU_$SYSTEM_REV): a packed record of 16
    bits (ref 3.10.7; fields from the most significant bit).  Bit 7 is
    set for the type 2 console keyboard (`kbd_type_sysrev'); with an FPX
    OS_$INIT requires bits 6..2 to be odd, bit 2 set
    (`fpx_eco_check'). }
  mmu_$sysrev_t = packed record
    rev_high: 0..255;                     { bits 15..8 }
    kbd_type_2: boolean;                  { bit 7 }
    bits_6_2: 0..31;                      { bits 6..2 }
    bits_1_0: 0..3;                       { bits 1..0 }
  end;

  { The memory error longword, +0x4..+0x7 of the MMU page: the whole
    longword (SAU2), and its bytes and words (SAU1 writes the first byte
    to re-enable parity checking and reads the word at +2).  `all' is
    base.ins.pas's name for status_$t's longword.  On the SAU6 the first
    word is the system revision. }
  mmu_$mem_err_t = record
    case integer of
      1: (all: integer32);                { 0x00..0x03 }
      2: (sau1_enable: char;              { 0x00 }
          byte_1: char;                   { 0x01 }
          word: mmu_$mem_err_word_t);     { 0x02 }
      3: (sysrev: mmu_$sysrev_t);         { 0x00..0x01 }
  end;

  { The MMU page as far as PARITY reads it.  The word at +2, the status,
    is a set (ref 3.9.3): member 0 is set on SAU1, member 1 an MMU
    parity error, member 4 MMU_$NORMAL_MODE's.  csr at +0 (the
    hand-written routines' MMU_CSR) is not read by compiled code here. }
  mmu_$status_t = set of 0..15;
  mmu_$regs_t = record
    csr: pinteger;                        { 0x00 }
    status: mmu_$status_t;                { 0x02 }
    mem_err: mmu_$mem_err_t;              { 0x04 }
  end;

  { One page frame table entry, 4 bytes: the ASID in bits 15..9 and the
    protection in bits 8..4 of the first word (mask 16#01F0), the hash
    link and flags in the second word.  The four bits below are the ones
    MMU_$PTOV takes as `entry & 16#F0000' (mmu/m68k/ptov.s). }
  mmu_$pft_entry_t = packed record
    asid: 0..127;                         { bits 31..25 }
    prot: 0..31;                          { bits 24..20 }
    bits_19_16: 0..15;                    { bits 19..16 }
    w_02: pinteger;                       { bits 15..0: link and flags }
  end;

var
  { MMU (map symbol, IODEFS). }
  mmu: extern mmu_$regs_t;

  { PFT (map symbol, IODEFS): one entry per physical page, element 0 at
    the symbol, indexed by a 16-bit page number.  4096 entries: the
    PFT's links are 12 bits (mask 16#0FFF). }
  pft: extern array[0..4095] of mmu_$pft_entry_t;
