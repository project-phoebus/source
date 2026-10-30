{ mem/mem.pas - the MEM_ module, the memory parity-error statistics.

  Image addresses:
    sau2  0x00E22930  MEM_ data (WIRED_DATA, 0x5C bytes)
    sau9  0x3C4256C0  MEM_ data (WIRED_DATA, 0x5C bytes)

  One compilation unit, one code segment and one data segment: the map's
  MEM_ code segment in WIRED_PROC (0xB8 bytes, MEM_$PARITY_LOG; the
  SAU9's 0x104 bytes, MEM_$INIT and MEM_$PARITY_LOG) and its
  MEM_ data segment in WIRED_DATA (0x5C bytes, MEM_$SIZE and
  MEM_$MEM_REC).  (The MEM_LITES code and data segments are another
  module, not this one.)

  The data, 0x5C bytes, zero but for MEM_$MEM_REC's first two words,
  both 2 (the SAU9's first word 16#2B); PARITY's block follows:

    +0x00  MEM_$SIZE     4     the SAU9's MEM_$INIT reads it
    +0x04  MEM_$MEM_REC  0x56  MEM_$PARITY_LOG's; ASKNODE_$INTERNET_INFO
                               copies it whole
    +0x5A  (2 bytes)           the block rounded up to a longword

  Both objects are map symbols, so they are the module's defined
  variables (ref 7.2.2, Method 2): extern in mem/mem.ins.pas, defined
  here, allocated in the order of the define list, which is the map's.
  The heading names wired_proc and wired_data.

  Build: dpc -I domain_os domain_os/mem/mem.pas.  Check:
  tools/pascal_check.sh.
}
module mem_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'mem/mem.ins.pas';
%if mem_ccr_board_size %then
%include 'mmu/mmu.ins.pas';
%endif

%if mem_ccr_board_size %then
const
  { The two board sizes in MB that MMU_CCR's bit 3 selects
    (mmu/mmu.ins.pas mmu_ccr). }
  mem_board_mb_small = 4;
  mem_board_mb_large = 16;

%endif

{ The global routines and variables this module defines (ref 7.3.4
  and 7.2.2, Method 2), in map order.  MEM_$MEM_REC's initial value:
  the words w_00 and n_boards are 2 (w_00 16#2B on the SAU9), the rest
  zero.  The reference leaves the
  fields an initializer does not name uninitialized (ref 3.11.1, p.
  3-38: "it does not initialize the other components", of an array);
  uninitialized data is zero in the image (LOG_'s and BITPAD's blocks)
  and dpc emits zeros. }
define
%if mem_ccr_board_size %then
  mem_$init;
%endif
  mem_$parity_log;
  mem_$size;
%if mem_ccr_board_size %then
  mem_$mem_rec := [w_00 := 16#2B, n_boards := 2];
%else
  mem_$mem_rec := [w_00 := 2, n_boards := 2];
%endif

{ ---- WIRED_PROC ---- }
%if mem_ccr_board_size %then
%include 'mem/init.pas';                    { MEM_$INIT }
%endif
%include 'mem/parity_log.pas';              { MEM_$PARITY_LOG }
