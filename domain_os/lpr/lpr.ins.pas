{ lpr/lpr.ins.pas - LPR_ (the line printer driver), for the Domain
  Pascal tree.

  Without the driver (the SR10.2 SAU2, SAU5..SAU9 kernels) what is left
  is LPR_$RELEASE, hand-written assembly (the map's LPR_ASM code segment,
  4 bytes; lpr/m68k/release.s).  With it (`lpr_driver',
  base/config.ins.pas) the driver of the parallel printer port at LPR:
  the module LPR_ (lpr/lpr.pas) and the hand-written LPR_ASM in .DATA
  (lpr/sau3/lpr_asm.s), whose interrupt routine sends the circular
  buffer's lines (cbuf/) to the port.  Include base/base.ins.pas before
  it; with the driver also cbuf/cbuf.ins.pas.
}

%if lpr_driver %then
const
  { The statuses, from stcode.db.10.2 ("OS / line printer module");
    16#001F000B .. 16#001F000D are in neither status database: named
    after the code that stores them. }
  status_$lpr_invalid_string_length = 16#001F0002;
                              { invalid string length }
  status_$lpr_invalid_string_termination = 16#001F0003;
                              { invalid string termination }
  status_$lpr_not_acquired = 16#001F0004;
                              { line printer not acquired }
  status_$lpr_already_acquired = 16#001F0005;
                              { line printer already acquired }
  status_$lpr_no_line_printer = 16#001F0009;
                              { no line printer on system }
  status_$lpr_in_use = 16#001F000B;
                              { acquired by another process }
  status_$lpr_invalid_mode = 16#001F000C;
                              { a mode other than 0..2 }
  status_$lpr_mode_unavailable = 16#001F000D;
                              { mode 2 while the port's word at 0x40 has
                                bit 9 set }

  { The longest line LPR_$WRITE takes. }
  lpr_max_line = 284;

%if lpr_pbu_unit %then
  { The PNA's statuses (stcode.db.10.2): "pna board not installed in
    system", which LPR_$ACQUIRE stores for PBU_$ACQUIRE_INT's "pbu not
    present"; 16#001F000A, in neither status database, LPR_$STATE's
    refusal of a mode (named after that use). }
  status_$lpr_no_pna = 16#001F0001;
  status_$lpr_mode_refused = 16#001F000A;

  { The printer's PBU unit (the PNA's level 6, the handbook's INT6 line
    printer vector), its CSR pages and sharing for PBU_$ACQUIRE_INT, and
    the mode LPR_$RELEASE gives PBU_$RELEASE_INT (mt/mt.ins.pas's
    mt_release_mode). }
  lpr_pbu_unit_number = 6;
  lpr_csr_pages = 1;
  lpr_sharing = 3;
  lpr_release_mode = 3;

  { lpr_state's flag member 7: the port ready (member 5 of PBU_CTL's
    word at +4). }
  lpr_flag_ready = 7;
  lpr_ready_bit = 5;
%else
  { lpr_state's flag members, from the port's status register: 7, no bit
    of 1..7 set; 6 and 5, its bits 1 and 2. }
  lpr_flag_status_clear = 7;
  lpr_flag_status_1 = 6;
  lpr_flag_status_2 = 5;
%endif
  lpr_mode_set = 7;

type
  lpr_$byte_t = [byte] 0..255;
  lpr_$bits_t = set of 0..7;
  lpr_$word_bits_t = set of 0..15;

%if not lpr_pbu_unit %then
  { The printer port's registers (map symbol LPR, the port's I/O page):
    bytes at even offsets, written as values and tested by their bits:
    a variant record (ref 3.10.3).  LPR_ASM's interrupt routine sends
    through data (0x10) while bit 0 of ready (0x1A) is set, and sets and
    clears the interrupt enable, bit 1 of the register at 0x0C.
    `[device]'. }
  lpr_$regs_t = [device] packed record
    case integer of
      1: (ctl: lpr_$byte_t;                       { 0x00 }
          unused_01: lpr_$byte_t;                 { 0x01 }
          reg_02: lpr_$byte_t;                    { 0x02 }
          unused_03: lpr_$byte_t;                 { 0x03 }
          reg_04: lpr_$byte_t;                    { 0x04 }
          unused_05: lpr_$byte_t;                 { 0x05 }
          reg_06: lpr_$byte_t;                    { 0x06 }
          unused_07: lpr_$byte_t;                 { 0x07 }
          reg_08: lpr_$byte_t;                    { 0x08 }
          unused_09: array[1..3] of lpr_$byte_t;  { 0x09 }
          reg_0c: lpr_$byte_t;                    { 0x0C }
          unused_0d: lpr_$byte_t;                 { 0x0D }
          reg_0e: lpr_$byte_t;                    { 0x0E }
          unused_0f: lpr_$byte_t;                 { 0x0F }
          data: lpr_$byte_t;                      { 0x10 }
          unused_11: array[1..7] of lpr_$byte_t;  { 0x11 }
          reg_18: lpr_$byte_t;                    { 0x18 }
          unused_19: lpr_$byte_t;                 { 0x19 }
          reg_1a: lpr_$byte_t);                   { 0x1A }
      2: (unused_b00: array[1..24] of lpr_$byte_t;  { 0x00 }
          status: lpr_$bits_t;                    { 0x18 }
          unused_b19: lpr_$byte_t;                { 0x19 }
          ready: lpr_$bits_t;                     { 0x1A }
          unused_b1b: array[1..37] of lpr_$byte_t;  { 0x1B }
          config: lpr_$word_bits_t);              { 0x40 }
  end;

  { A mode's register values: the control register's two writes, the
    registers at 0x08 and 0x18, and the data mask. }
  lpr_$mode_t = record
    ctl_first: lpr_$byte_t;               { 0x00 }
    reg_08: lpr_$byte_t;                  { 0x01 }
    reg_18: lpr_$byte_t;                  { 0x02 }
    ctl_second: lpr_$byte_t;              { 0x03 }
    mask: lpr_$byte_t;                    { 0x04 }
  end;
%endif

  { LPR_$STATE's word: the port's flags (above) and the mode, whose
    member 7 asks for the mode in its low two bits to be set: the mode
    byte as a number and as a set (a variant record, ref 3.10.3). }
  lpr_$state_t = packed record
    case integer of
      1: (flags: lpr_$bits_t;             { 0x00 }
          mode: lpr_$byte_t);             { 0x01 }
      2: (unused_flags: lpr_$bits_t;      { 0x00 }
          mode_bits: lpr_$bits_t);        { 0x01 }
  end;



  { A line, as LPR_$WRITE's caller passes it. }
  lpr_$line_t = array[1..lpr_max_line] of char;

var
  { LPR_$BCB and LPR_$PRESENT (map symbols in LPR_'s .DATA block,
    `define'd in lpr/lpr.pas): the circular buffer's control block, which
    LPR_ASM's interrupt routine reads and releases, and whether the port
    answered LPR_$INIT's probe. }
  lpr_$bcb: extern cbuf_$cb_t;
  lpr_$present: extern boolean;

  { LPR_ASM's data (map symbols, lpr/sau3/lpr_asm.s, lpr/sau4/lpr_asm.s):
    the data mask the interrupt routine applies (a word; not with
    `lpr_pbu_unit'), whether an interrupt is expected (a byte), the count
    of interrupt starts, and the buffer (512 bytes). }
%if not lpr_pbu_unit %then
  lpr_$data_mask: extern integer;
%endif
  lpr_$int_expected: extern boolean;
  lpr_$ir_start_count: extern integer;
  lpr_$buffer: extern array[1..512] of char;

  { LPR (map symbol, the port's I/O page) and LPR_VEC (map symbol, the
    trap page's cell 0x74, the level 5 autovector): LPR_$INIT stores
    LPR_$INT's address there. }
%if not lpr_pbu_unit %then
  lpr: extern lpr_$regs_t;
  lpr_vec: extern univ_ptr;
%endif

  { The markers of the driver's wired range (map symbols):
    LPR_$PROC_START (the first byte of LPR_'s .TEXT code, the
    module-local lpr_set_mode), LPR_$PROC_END (lpr/m68k/end_addr.s),
    LPR_$DATA_START (the .DATA block's first byte) and LPR_$DATA_END (the
    last byte of LPR_ASM's buffer); only their addresses are used. }
  lpr_$proc_start: extern char;
  lpr_$proc_end: extern char;
  lpr_$data_start: extern char;
  lpr_$data_end: extern char;

{ ---- LPR_ASM's routines (hand assembly, lpr/sau3/lpr_asm.s). ---- }

{ LPR_$MOVE_DATA - copy a line into the buffer: by bytes when the
  destination is odd, else by words.  The arguments off the stack: the
  source, the destination pointer's address, the length's address. }
procedure lpr_$move_data(in src: univ lpr_$line_t; in dst: univ_ptr;
                         in len: integer); extern;

{ LPR_$INT - the port's interrupt routine (LPR_VEC; with `lpr_pbu_unit'
  the PBU unit's device routine); only its address is used. }
procedure lpr_$int; extern;

%if not lpr_pbu_unit %then
{ LPR_$ENABLE_INT and LPR_$DISABLE_INT - enable and disable the port's
  interrupt. }
procedure lpr_$enable_int; extern;
procedure lpr_$disable_int; extern;
%endif
%endif

{ ---- The module's global routines (lpr/lpr.pas), in map order. ---- }

%if lpr_driver %then
{ LPR_$INIT - probe the line printer port and set it up. }
procedure lpr_$init; extern;

{ LPR_$STATE - the port's state; set its mode. }
procedure lpr_$state(in out state: lpr_$state_t; out status: status_$t);
  extern;

{ LPR_$WRITE - queue a line for the printer. }
procedure lpr_$write(in line: univ lpr_$line_t; in len: integer;
                     out status: status_$t); extern;

{ LPR_$ACQUIRE - acquire the line printer for the calling process. }
procedure lpr_$acquire(out status: status_$t); extern;
%endif

{ LPR_$RELEASE - release the line printer, after the queued lines when
  wait is true.  Without the driver a bare return (lpr/m68k/release.s):
  the one caller, PROC2_$CLEANUP_HANDLERS_INTERNAL, passes two
  addresses, a constant word cell, then its status.

  A constant by address is a literal passed to an `in' parameter: `in'.
  Its type is boolean, the literal `false': PROC2_$GET_ASID passes the
  same cell as PROC2_$FIND_ASID's `in' boolean use_alt, and a later
  routine shares an earlier cell only for a literal of the same bytes and
  type (`false' in the word's high byte).  CT_$RELEASE's unit, an integer
  0, has a cell of its own.  `dpc -o' pools GET_ASID's `false' with this
  cell as the image does.  With the driver the body tests the byte's
  sign, a boolean.  The status is `out'. }
procedure lpr_$release(in wait: boolean; out status_ret: status_$t); extern;
