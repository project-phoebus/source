{ parity/parity.pas - the PARITY module, memory parity error handling.

  Image addresses:
    sau2  0x00E2298C  PARITY data (WIRED_DATA, 4 bytes)
    sau7  0x3C427C34  PARITY data (WIRED_DATA, 0x24 bytes)
    sau8  0x03C242E4  PARITY data (WIRED_DATA, 0x24 bytes)
    sau9  0x3C42571C  PARITY data (WIRED_DATA, 0x18C bytes)

  One compilation unit, one code segment and one data segment: the
  map's PARITY code segment in WIRED_PROC (0x354 bytes, PARITY_$CHK and
  PARITY_$CHK_IO; the SAU9's 0x3EC bytes and the SAU8's 0x320, with
  PARITY_$SET_STATE after them) and its PARITY data segment in
  WIRED_DATA.

  The data, zero in the image:

    +0x00  PARITY_$DURING_DMA  1    PARITY_$CHK stores it twice;
                                    PARITY_$CHK_IO clears it
    +0x01  (3 bytes)                the block rounded up to a longword

  With `parity_dma_pages' (the SAU9's 0x18C bytes):

    +0x00  PARITY_$DMA_TABLE   0x18C  three channels of 0x84 bytes:
                                      PARITY_$SET_STATE fills one,
                                      PARITY_$CHK flags it,
                                      PARITY_$CHK_IO clears it

  With `parity_dma_page_pairs' (the SAU8's 0x24 bytes):

    +0x00  PARITY_$DMA_TABLE   0x24   three channels of 0x0C bytes, two
                                      pages each: PARITY_$SET_STATE
                                      fills one, PARITY_$CHK flags a
                                      page, PARITY_$CHK_IO reports and
                                      clears it

  The one object is a map symbol, so it is the module's defined
  variable (ref 7.2.2, Method 2), extern in parity/parity.ins.pas, as
  MEM_'s are (mem/mem.pas).  The heading names wired_proc and
  wired_data.

  The parity state the routines work on, PARITY_$INFO, is not this
  module's: it lies in the hand-written FIM's data (FIM_WIRED)
  (parity/parity.ins.pas).

  Build: dpc -I domain_os domain_os/parity/parity.pas.  Check:
  tools/pascal_check.sh.
}
module parity, wired_proc, wired_data;

{ Without `memory_parity' (the SAU4, whose memory has error correction,
  mem/eccc_log.pas) the module is empty. }
%include 'base/base.ins.pas';
%if memory_parity %then
%include 'ec/ec.ins.pas';
%include 'fim/fim.ins.pas';
%include 'misc/crash_system.ins.pas';
%if pft_mmu %then
%include 'mmu/mmu.ins.pas';
%else

{ TODO(pascal) MMU's headings for the other MMU belong in mmu/mmu.ins.pas

  Without the page frame table MMU (`pft_mmu') MMU_$REMOVE takes a
  virtual address and a word (PARITY_$CHK passes PAR_BUFF and 0), where
  mmu/mmu.ins.pas declares the one-argument form its other callers use
  under every configuration.  As os/os.pas and win_scsi/win_scsi.ins.pas
  do, this module declares the MMU headings and register it uses here,
  as mmu/mmu.ins.pas has them but MMU_$REMOVE, and does not include that
  file, until it carries the other form under a part of its own, once
  every caller has its form. }

{ MMU_$REMOVE (hand assembly): a page's mapping removed; the address and
  a word, by value. }
procedure mmu_$remove(va: univ_ptr; flags: integer);
  options(extern, val_param);

{ MMU_$INSTALL (hand assembly): the page number and the virtual address,
  longwords, then the ASID and the protection, all by value. }
procedure mmu_$install(ppn: integer32; va: univ_ptr; asid: integer;
                       prot: integer);
  options(extern, val_param);

%if parity_err_regs %then
type
  { The MMU control register's first byte at MMU_CCR
    (mmu/mmu.ins.pas). }
  mmu_$ccr_reg_t = [device] packed record
    bits_7_5: 0..7;                       { bits 7..5 }
    bit_4: boolean;                       { bit 4 }
    small_boards: boolean;                { bit 3 }
    bit_2: boolean;                       { bit 2 }
    bits_1_0: 0..3;                       { bits 1..0 }
  end;

var
  { MMU_CCR (map symbol of the I/O definitions, without `$'). }
  mmu_ccr: extern mmu_$ccr_reg_t;
%endif
%endif
%include 'cache/cache.ins.pas';
%include 'time/time.ins.pas';
%include 'log/log.ins.pas';
%include 'mem/mem.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'parity/parity.ins.pas';
%if parity_cpu_status %then
type
  { The CPU control register's word, and MMU_$PID_PRIV, the copy of it
    the hand-written MMU routines keep and write to it: the address
    space id in the high byte, the privilege byte below it.  PARITY_$CHK
    clears bit 0 of the privilege byte while the failing page is read
    and sets it after, each time writing the byte to the register. }
  mmu_$pid_priv_t = packed record
    case integer of
      1: (pid: 0..255;                    { bits 15..8 }
          priv: 0..255);                  { bits 7..0 }
      2: (bits_15_1: 0..32767;            { bits 15..1 }
          bit_0: boolean);                { bit 0 }
  end;

  { MMU's page as PARITY_$CHK reaches it: the CPU status register's
    word at +0 and the CPU control register's at +0x100 (the Technical
    Reference's two registers, a page apart); with `parity_cache_check'
    the physical cache's register at +0x200. }
  mmu_$cpu_regs_t = [device] record
    status: parity_$cpu_status_t;         { 0x000 }
    unused_002: array[1..127] of integer; { 0x002 }
    control: mmu_$pid_priv_t;             { 0x100 }
%if parity_cache_check %then
    unused_102: array[1..127] of integer; { 0x102 }
    cache: parity_$cache_status_t;        { 0x200 }
%endif
  end;

  { The latch-page-on-parity-error register's word. }
  mmu_$parity_ppn_reg_t = [device] pinteger;

var
  { MMU (map symbol of the I/O definitions, without `$'). }
  mmu: extern mmu_$cpu_regs_t;

  { MMU_$PID_PRIV (map symbol, the first word of the hand-written
    MMU_ASM's data). }
  mmu_$pid_priv: extern mmu_$pid_priv_t;

  { MMU_$PARITY_PPN (map symbol of the I/O definitions): the Technical
    Reference's latch-page-on-parity-error register, the failing page's
    number in its low 14 bits. }
  mmu_$parity_ppn: extern mmu_$parity_ppn_reg_t;
%if parity_cache_check %then

  { ROADRUNNER (map symbol without `$', in the hand-written MMU_ASM's
    data): a boolean, its first byte's sign, set on the boards with the
    physical cache (mmu/mmu.ins.pas declares it too, a file this module
    does not include). }
  roadrunner: extern boolean;
%endif
%endif

{ The global routines and variable this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order.  The variable is uninitialized, zero
  in the image (MEM_'s and BITPAD's blocks). }
define
  parity_$chk;
  parity_$chk_io;
%if parity_dma_pages or parity_dma_page_pairs %then
  parity_$set_state;
  parity_$dma_table;
%else
  parity_$during_dma;
%endif

{ ---- WIRED_PROC ---- }
%include 'parity/chk.pas';                  { PARITY_$CHK }
%include 'parity/chk_io.pas';               { PARITY_$CHK_IO }
%if parity_dma_pages or parity_dma_page_pairs %then
%include 'parity/set_state.pas';            { PARITY_$SET_STATE }
%endif
%endif
