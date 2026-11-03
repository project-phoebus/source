{ mem/mem.pas - the MEM_ module, the memory parity-error statistics.

  Image addresses:
    sau2  0x00E22930  MEM_ data (WIRED_DATA, 0x5C bytes)
    sau4  0x0F824CB4  MEM_ data (WIRED_DATA, 0x64 bytes)
    sau8  0x03C24288  MEM_ data (WIRED_DATA, 0x5C bytes)
    sau9  0x3C4256C0  MEM_ data (WIRED_DATA, 0x5C bytes)

  One compilation unit, one code segment and one data segment: the map's
  MEM_ code segment in WIRED_PROC (0xB8 bytes, MEM_$PARITY_LOG; the
  SAU9's 0x104 bytes and the SAU8's 0x250, MEM_$INIT and
  MEM_$PARITY_LOG; the SAU4's 0x214, MEM_$INIT and MEM_$ECCC_LOG, with
  `ecc_memory' and without `memory_parity') and its
  MEM_ data segment in WIRED_DATA (0x5C bytes, MEM_$SIZE and
  MEM_$MEM_REC).  (The MEM_LITES code and data segments are another
  module, not this one.)

  The data, 0x5C bytes, zero but for MEM_$MEM_REC's first two words,
  both 2 (the SAU9's first word 16#2B; the SAU8's second 0); PARITY's
  block follows:

    +0x00  MEM_$SIZE     4     the SAU9's MEM_$INIT reads it
    +0x04  MEM_$MEM_REC  0x56  MEM_$PARITY_LOG's; ASKNODE_$INTERNET_INFO
                               copies it whole
    +0x5A  (2 bytes)           the block rounded up to a longword

  With `ecc_memory' (the SAU4's 0x64 bytes, MEM_$MEM_REC's first word 1):

    +0x00  mem_board_slot 8    each board's controller slot (MEM_$INIT)
    +0x08  MEM_$SIZE      4
    +0x0C  MEM_$MEM_REC   0x56 MEM_$ECCC_LOG's
    +0x62  (2 bytes)           the block rounded up to a longword

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
%if ecc_memory %then
%include 'ml/ml.ins.pas';
%include 'ec/ec.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'time/time.ins.pas';
%include 'log/log.ins.pas';
%include 'fim/fim.ins.pas';
%include 'io/io.ins.pas';                   { TESTPAGE }
%endif
%if mem_board_jumpers %then
%include 'ml/ml.ins.pas';
%include 'ec/ec.ins.pas';
%include 'time/time.ins.pas';
%include 'sio/sio.ins.pas';
%include 'sio2681/sio2681.ins.pas';

var
  { SIO (map symbol of the I/O definitions, without `$'): the 2681
    DUART, whose input port (IPR) holds the memory configuration's
    bits. }
  sio: extern sio2681_$regs_t;

const
  { The input port's bits that give the memory configuration. }
  mem_config_mask = 16#74;
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
%if ecc_memory %then
var
  { +0x00: each board's controller slot, 1..mem_ecc_slots, 0 for no
    board (MEM_$INIT), the module's own variable before the two map
    symbols. }
  mem_board_slot: array[1..mem_ecc_boards] of integer;

%endif
define
%if mem_ccr_board_size or mem_board_jumpers or ecc_memory %then
  mem_$init;
%endif
%if ecc_memory %then
  mem_$eccc_log;
%endif
%if memory_parity %then
  mem_$parity_log;
%endif
  mem_$size;
%if ecc_memory %then
  mem_$mem_rec := [w_00 := 1];
%elseif mem_ccr_board_size %then
  mem_$mem_rec := [w_00 := 16#2B, n_boards := 2];
%elseif mem_board_jumpers %then
  mem_$mem_rec := [w_00 := 2];
%else
  mem_$mem_rec := [w_00 := 2, n_boards := 2];
%endif

{ ---- WIRED_PROC ---- }
%if mem_ccr_board_size or mem_board_jumpers or ecc_memory %then
%include 'mem/init.pas';                    { MEM_$INIT }
%endif
%if ecc_memory %then
%include 'mem/eccc_log.pas';                { MEM_$ECCC_LOG }
%endif
%if memory_parity %then
%include 'mem/parity_log.pas';              { MEM_$PARITY_LOG }
%endif
