{ mmu/mmu.ins.pas - MMU_$ routines, for the Domain Pascal tree.

  The MMU_$ routines are hand-written assembly (in the map's MMU_ASM
  data segment, mmu/README.md; mmu/m68k/*.s): these are the
  headings Pascal callers compile against.  The routine and variable
  names are the map's.
}

{ MMU_$NORMAL_MODE: no arguments; a boolean in D0, from a bit of the
  MMU status register. }
function mmu_$normal_mode: boolean; extern;

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

  { The memory error longword, +0x4..+0x7 of the MMU page: the whole
    longword (SAU2), and its bytes and words (SAU1 writes the first byte
    to re-enable parity checking and reads the word at +2).  `all' is
    base.ins.pas's name for status_$t's longword. }
  mmu_$mem_err_t = record
    case integer of
      1: (all: integer32);                { 0x00..0x03 }
      2: (sau1_enable: char;              { 0x00 }
          byte_1: char;                   { 0x01 }
          word: mmu_$mem_err_word_t);     { 0x02 }
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

%if large_vm %then
{ MMU_$REMOVE (hand assembly, mmu/sau9/mmu_asm.s): the page at a virtual
  address made not resident; the address and a word, by value
  (`val_param'). }
procedure mmu_$remove(va: univ_ptr; flags: integer);
  options(extern, val_param);
%else
{ MMU_$REMOVE (hand-written, mmu/m68k/remove.s): the page number by
  value (`val_param'). }
procedure mmu_$remove(ppn: integer32); options(extern, val_param);
%endif

{ MMU_$INSTALL (hand-written, mmu/m68k/install.s): the page number and
  the virtual address, longwords, then the ASID and the protection, the
  low bytes of two words, all by value (`val_param'). }
procedure mmu_$install(ppn: integer32; va: univ_ptr; asid: integer;
                       prot: integer);
  options(extern, val_param);

{ MMU_$PTOV (hand-written, mmu/m68k/ptov.s): the page number by value
  (`val_param'); the virtual address in D0, 0 for a page with no
  link. }
function mmu_$ptov(ppn: integer32): integer32; options(extern, val_param);

var
  { M68020 (map symbol without `$', the second word of the hand-written
    MMU_ASM's data; 0 in the image, set at boot): a boolean, its first
    byte's sign. }
  m68020: extern boolean;
%if large_address_space %then
  { MMU_$RARS_PHADDR (map symbol in the hand-written MMU_ASM's data):
    the physical address of each ASID's RARS page, longwords indexed by
    ASID (MST_$INIT and MST_$ALLOC_ASID store the page number times
    1024; MMU_$INSTALL_ASID reads it). }
  mmu_$rars_phaddr: extern array[0..57] of integer32;
%endif

{ MMU_$VTOP (hand-written, mmu/m68k/vtop.s): the virtual address by
  value (`val_param'); the page number in D0; the status status_$ok or
  16#00070001. }
function mmu_$vtop(va: integer32; out status: status_$t): integer32;
  options(extern, val_param);

{ MMU_$CACHE_INHIBIT_VA (hand assembly in MMU's run: an empty routine on
  the SAU2): the address by value (`val_param'). }
procedure mmu_$cache_inhibit_va(va: univ_ptr); options(extern, val_param);

{ MMU_$INSTALL_PRIVATE (hand-written, in MMU_ASM's run beside
  MMU_$INSTALL): MMU_$INSTALL's four arguments by value (`val_param'). }
procedure mmu_$install_private(ppn: integer32; va: univ_ptr; asid: integer;
                               prot: integer);
  options(extern, val_param);

{ MMU_$MCR_CHANGE (map symbol, MARKED; hand-written in MMU_ASM's run,
  mmu/m68k/mcr_change.s): the bit number of the memory control register
  to change, a word by value (`val_param'). }
procedure mmu_$mcr_change(bit: integer); options(extern, val_param);

{ MMU_$INSTALL_ASID (hand assembly, MMU_ASM): the new PROC1_$AS_ID, a
  word by value (`val_param'). }
procedure mmu_$install_asid(asid: integer); options(val_param, extern);

{ MMU_$POWER_OFF (map symbol; hand-written in MMU_ASM's run): no
  arguments; a boolean in D0, true while bit 2 of the MMU status word is
  set (the keyswitch off). }
function mmu_$power_off: boolean; extern;

type
  mmu_$ppn_list_t = array[1..32] of integer32;

{ MMU_$REMOVE_LIST (hand assembly in MMU_ASM, no frame): a list of page
  numbers by address and a count word by value.  The list type is MMU's
  own, 32 longwords as AST_'s ast_$ppn_list_t, so that this file needs
  no AST_ insert; the formal is `univ'. }
procedure mmu_$remove_list(in ppn_array: univ mmu_$ppn_list_t;
                           count: integer);
  options(extern, val_param);

{ MMU_$INSTALL_LIST (map symbol; hand assembly in MMU_ASM, no frame):
  the count word, the list by address, the virtual address, and the
  ASID and protection in the low bytes of two words; all but the list by
  value (`val_param').  The list is MMU_$REMOVE_LIST's type. }
procedure mmu_$install_list(count: integer;
                            in ppn_array: univ mmu_$ppn_list_t;
                            va: integer32; asid: integer; prot: integer);
  options(extern, val_param);

{ Three entries of the hand-written MMU_ASM (mmu/m68k/init.s,
  set_sysrev.s, set_prot.s): MMU_$INIT and MMU_$SET_SYSREV take no
  arguments; MMU_$SET_PROT the page number and a protection word, by
  value (`val_param'). }
procedure mmu_$init; extern;
procedure mmu_$set_sysrev; extern;
procedure mmu_$set_prot(ppn: integer32; prot: integer);
  options(extern, val_param);

{ MMU_$CLR_USED (map symbol; hand assembly in MMU_ASM's run,
  mmu/m68k/clr_used.s): clears the referenced bit of a PFT entry; the
  page number by value (`val_param').  The routine reads the high half
  of that longword. }
procedure mmu_$clr_used(ppn: integer32); options(extern, val_param);

{ MMU_$GET_PMAPE_ADDR and MMU_$SET_PMAPE (map symbols of the SAU7..SAU9
  MMU code, hand assembly): the address of the page table entry that
  maps a virtual address, in A0; and the entry at that address set to a
  page number (shifted into place with the valid bits), the address's
  translation flushed.  Everything by value (`val_param'); the SAU9's
  SCSI driver calls them. }
function mmu_$get_pmape_addr(va: univ_ptr): univ_ptr;
  options(extern, val_param);
procedure mmu_$set_pmape(va: univ_ptr; pmape: univ_ptr; ppn: integer32);
  options(extern, val_param);

{ MMU_$PURGE (map symbol of the SAU9's MMU code, hand assembly): flush
  the address translation cache and the virtual cache; no arguments. }
procedure mmu_$purge; extern;

{ MMU_$PURGE_TB (map symbol of the SAU9's MMU code, hand assembly, a
  branch to MMU_$PURGE): flush the translation cache; a word and a
  longword by value (`val_param'), not read by the SAU9's code. }
procedure mmu_$purge_tb(kind: integer; va: integer32);
  options(extern, val_param);

{ MMU_$SYSTEM_REV (map symbol, the longword before MMU_$SET_SYSREV in
  the hand-written MMU_ASM code, zero in the image). }
var
  mmu_$system_rev: extern integer32;

type
  { An interrupt select field of the SAU9's MMU interrupt mask register
    (below): which of a system bus level's AT bus interrupts reaches it
    (atbus/atbus.pas's table gives each interrupt's value). }
  mmu_$imr_select_t = 0..3;

  { The SAU9's MMU interrupt mask register's byte, as ATBUS_$DEFINE_INT
    changes it: a packed record of 8 bits (ref 3.10.7; fields from the
    most significant bit) with two variants.
    - 1, the select fields: level2_select for system bus level 2,
      level13_select shared by levels 1 and 3; bits 7..4 are not
      changed there.
    - 2, the whole byte, which ATBUS_$DEFINE_INT copies from MMU_$IMR_COPY
      to MMU_IMR. }
  mmu_$imr_t = packed record
    case integer of
      1: (bits_7_4: 0..15;                { bits 7..4 }
          level2_select: mmu_$imr_select_t;
                                          { bits 3..2 }
          level13_select: mmu_$imr_select_t);
                                          { bits 1..0 }
      2: (all: 0..255);                   { bits 7..0 }
  end;

  { The register itself, `[device]' (ref 3.15.3). }
  mmu_$imr_reg_t = [device] mmu_$imr_t;

var
  { MMU_$IMR_COPY (map symbol, the first object of the SAU9's
    hand-written MMU_ASM data): the copy of the interrupt mask register
    that ATBUS_$DEFINE_INT changes and writes to it. }
  mmu_$imr_copy: extern mmu_$imr_t;

  { MMU_IMR (map symbol of the SAU9's I/O definitions, without `$'):
    the register. }
  mmu_imr: extern mmu_$imr_reg_t;

type
  { The SAU9's MMU control register's first byte at MMU_CCR, as
    MEM_$INIT and MEM_$PARITY_LOG read it: bit 3 set for 4 MB memory
    boards, clear for 16 MB ones.  PARITY_$CHK sets bit 4 for a
    CACHE_$CLEAR and clears it after (FIM_$NMI clears it first), and
    sets bit 2 while PAR_BUFF maps the failing page.  The other bits are
    the MMU's (MMU_$INSTALL_ASID changes bit 7, mmu/sau9/mmu_asm.s).
    `[device]' (ref 3.15.3). }
  mmu_$ccr_reg_t = [device] packed record
    bits_7_5: 0..7;                       { bits 7..5 }
    bit_4: boolean;                       { bit 4 }
    small_boards: boolean;                { bit 3 }
    bit_2: boolean;                       { bit 2 }
    bits_1_0: 0..3;                       { bits 1..0 }
  end;

var
  { MMU_CCR (map symbol of the SAU9's I/O definitions, without `$'):
    the register. }
  mmu_ccr: extern mmu_$ccr_reg_t;

{ MMU_$INSTALL_SPECIAL (map symbol; hand assembly in the SAU9's
  MMU_ASM): install a physical page at a virtual address of a special
  segment; MMU_$INSTALL's four arguments by value (`val_param'). }
procedure mmu_$install_special(ppn: integer32; va: univ_ptr; asid: integer;
                               prot: integer);
  options(extern, val_param);

{ MMU_$REMOVE_SPECIAL_SEG (map symbol; hand assembly in the SAU9's
  MMU_ASM): remove a special segment's pages from an address space; the
  segment's address, the ASID and a third word, by value
  (`val_param'). }
procedure mmu_$remove_special_seg(va: univ_ptr; asid: integer;
                                  flag: integer);
  options(extern, val_param);
