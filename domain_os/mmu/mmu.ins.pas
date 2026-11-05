{ mmu/mmu.ins.pas - MMU_$ routines, for the Domain Pascal tree.

  The MMU_$ routines are hand-written assembly (in the map's MMU_ASM
  data segment, mmu/README.md; mmu/m68k/*.s): these are the
  headings Pascal callers compile against.  The routine and variable
  names are the map's.
}

{ MMU_$NORMAL_MODE: no arguments; a boolean in D0, from a bit of the
  MMU status register. }
function mmu_$normal_mode: boolean; extern;

{ The MMU page and the page frame table (map symbols MMU and PFT). }
%include 'mmu/mmu_page.ins.pas';

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
%if smap_shared_global_68851 %then
  { M68030 (map symbol without `$', in the hand-written MMU_ASM's data):
    a boolean, its first byte's sign, true when the CPU is an MC68030
    (MST_$TOUCH, mst_$va_to_aste). }
  m68030: extern boolean;

  { ROADRUNNER (map symbol without `$', in the hand-written MMU_ASM's
    data, after M68030): a boolean, its first byte's sign
    (COLOR7_$IOINIT). }
  roadrunner: extern boolean;
%endif
%if vm_regions %then
  { MMU_$RARS_PHADDR (map symbol in the hand-written MMU_ASM's data):
    the physical address of each ASID's root entries in RARS, longwords
    indexed by ASID (MST_$INIT and MST_$ALLOC_ASID store it;
    MMU_$INSTALL_ASID reads it). }
  mmu_$rars_phaddr: extern array[0..57] of integer32;

  { MMU_$OS_PMAPS_PHADDR (map symbol in the hand-written MMU_ASM's data):
    the physical address of OS_PMAPS, the global segments' page maps
    (OS_$COLD_START stores it). }
  mmu_$os_pmaps_phaddr: extern integer32;
%endif
%if region_registers %then
{ MMU_$INSTALL_REGION (hand assembly, the MMU_ASM block of the region
  registers' MMU): load region register `region' (its low five bits) of
  the current address space with `rar'.  Both by value off the stack;
  mst_$free_region passes a RARS entry's longword. }
procedure mmu_$install_region(region: integer; rar: integer32);
  options(extern, val_param);
%endif
%if run_time_layout %then
  { MMU_$HAVE_PMMU (map symbol in the hand-written MMU_ASM's data): a
    boolean, its first byte's sign, true when the node has the MC68851
    PMMU (MST_$PRE_INIT, AS_$INIT). }
  mmu_$have_pmmu: extern boolean;
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
