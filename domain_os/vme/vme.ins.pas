{ vme/vme.ins.pas - VME_ (the VME bus) constants, types, variables and
  routine headings, for the Domain Pascal tree.

  The VME_ module (vme/vme.pas), with the part vme_bus
  (base/config.ins.pas).  Include base/base.ins.pas,
  misc/crash_system.ins.pas, time/time.ins.pas, io/io.ins.pas and
  mbus/mbus.ins.pas before it.
}

const
  { The VME bus manager's statuses (the SR10.2 status-code database,
    "OS / vme bus manager": "(270001) undefined vme interrupt",
    "(270002) vme bus error"). }
  status_$vme_undefined_interrupt = 16#00270001;
  status_$vme_bus_error = 16#00270002;

  { "(80026) unrecognized interrupt from disktape controller" (OS /
    disk manager): VME_$INT crashes with it when the disk and tape
    controller's level interrupts and neither of the two status bits is
    set. }
  status_$unrecognized_disktape_interrupt = 16#00080026;

  { The interrupt vectors VME_$INIT installs, 28 and 29: the map's
    VME_VEC (0x70) and VME_ERR_VEC (0x74) of the trap page. }
  vme_vector = 16#1C;
  vme_err_vector = 16#1D;

  { The VME interrupt levels VME_$INT_VEC has entries for, 0..7 (0x40
    bytes): VME_$INT scans them from 7 down, VME_$DEFINE_INT accepts an
    id below the count. }
  vme_$max_level = 7;
  vme_$n_levels = 8;

  { The user interrupts VME_$USER_VEC has entries for, 0..15 (0x80
    bytes): VME_$USER_INT takes the low four bits of its vector.  With
    `vme_vectored_ints' 8..15 (0x40 bytes), user interrupt n on vector
    vme_$user_vector_base + n (the trap page's VME_VEC8 .. VME_VECF),
    the eight vectors from vme_$first_user_vector. }
%if vme_vectored_ints %then
  vme_$first_user_int = 8;
  vme_$n_user_ints = 8;
  vme_$user_vector_base = 16#F0;
  vme_$first_user_vector = 16#F8;
%else
  vme_$first_user_int = 0;
%endif
  vme_$max_user_int = 15;

  { The cartridge tape's controller type, ctype 5 (the SAU5's
    CTAPE_DCTE), on which VME_$INIT switches, is io/io.ins.pas's
    io_ctype_ctape. }

type
  { A VME interrupt handler, the same shape as the Multibus's
    (mbus/mbus.ins.pas): called with the argument stored beside it (or,
    for some levels, the vector the bus delivered), one longword by
    value; a boolean result, which VME_$INT does not read for these
    vectors.  VME_$UNDEF_INT and VME_$USER_INT are such functions. }
  vme_$handler_t = ^function(handler_arg: univ_ptr): boolean;
    options(val_param);

  { An entry of VME_$INT_VEC and VME_$USER_VEC, 8 bytes: the handler and
    its argument (VME_$DEFINE_INT and VME_$DEFINE_USERINT index them by
    the id shifted left 3). }
  vme_$int_vec_entry_t = record
    handler: vme_$handler_t;              { 0x00 }
    handler_arg: univ_ptr;                { 0x04 }
  end;

  { VME_CTL's word at 0x30, as the routines reach it: bit 3, which
    OS_$SHUTDOWN clears to power the machine down, and the 3-bit field
    that VME_$SAVE_VME copies, sign extended (bits 2..0 of the byte at
    0x31).  A packed record, the first field taking the high bits (ref
    3.10.7). }
  vme_$ctl_30_t = packed record
    unused: 0..4095;                      { bits 15..4 }
    power: boolean;                       { bit 3 }
    field: -4..3;                         { bits 2..0 }
  end;

  { The VME bus adapter's registers at VME_CTL, as the VME_ routines
    reach them: iack, one word per level (the vector of the level
    served); int_status, a bit per level, clear while the level
    interrupts; the words at 0x20..0x90 VME_$SAVE_VME copies.
    `[device]'.  The size past 0x92 is not seen. }
  vme_$ctl_t = [device] record
    iack: array[0..vme_$max_level] of pinteger;   { 0x00 }
    int_status: set of 0..15;             { 0x10 }
    unused_12: array[1..7] of integer;    { 0x12 }
    word_20: integer;                     { 0x20 }
    unused_22: array[1..7] of integer;    { 0x22 }
    ctl_30: vme_$ctl_30_t;                { 0x30 }
    unused_32: array[1..7] of integer;    { 0x32 }
    word_40: integer;                     { 0x40 }
    unused_42: array[1..7] of integer;    { 0x42 }
    word_50: integer;                     { 0x50 }
    unused_52: array[1..7] of integer;    { 0x52 }
    word_60: integer;                     { 0x60 }
    unused_62: array[1..7] of integer;    { 0x62 }
    word_70: integer;                     { 0x70 }
    unused_72: array[1..7] of integer;    { 0x72 }
    word_80: integer;                     { 0x80 }
    unused_82: array[1..7] of integer;    { 0x82 }
    word_90: integer;                     { 0x90 }
  end;

  { The disk and tape controller's register page as VME_$INT reads it:
    the word at 2, whose bits 11 and 9 tell the disk's interrupt from the
    tape's.  `[device]' as the other register pages. }
  vme_$dt_ctl_t = [device] record
    unused_00: integer;                   { 0x00 }
    int_status: set of 0..15;             { 0x02 }
  end;

  { VME_$SAVE, the bus state VME_$SAVE_VME copies at a bus error, 0x18
    bytes: the clock's high half, then VME_CTL's words in the order of
    their offsets (VME_$ERR_INT tests word_60's bit 14).  The last word
    is not written.  Each field is named after its register.  With
    `vme_vectored_ints' 0x14 bytes, defined with VME_$SAVE_VME in
    vme/sau6/vme_asm.s: the clock's high half and the turbo boards'
    adapter's words at 0x00, 0x06, 0x08, 0x0A, 0x60, 0x70, 0x80, 0x90. }
%if vme_vectored_ints %then
  vme_$save_t = record
    clock: time_$clockh_t;                { 0x00 }
    word_00: integer;                     { 0x04 }
    word_06: integer;                     { 0x06 }
    word_08: integer;                     { 0x08 }
    word_0a: integer;                     { 0x0A }
    word_60: integer;                     { 0x0C }
    word_70: integer;                     { 0x0E }
    word_80: integer;                     { 0x10 }
    word_90: integer;                     { 0x12 }
  end;
%else
  vme_$save_t = record
    clock: time_$clockh_t;                { 0x00 }
    int_status: set of 0..15;             { 0x04 }
    word_20: integer;                     { 0x06 }
    field_30: integer;                    { 0x08 }
    word_40: integer;                     { 0x0A }
    word_50: integer;                     { 0x0C }
    word_60: integer;                     { 0x0E }
    word_70: integer;                     { 0x10 }
    word_80: integer;                     { 0x12 }
    word_90: integer;                     { 0x14 }
    unused_16: integer;                   { 0x16 }
  end;
%endif

var
  { The module's data block, the map's VME_ data segment in WIRED_DATA
    (0xD8 bytes; map symbols at +0x00, +0x18, +0x98).  Defined, with
    the handlers' initial values, in vme/vme.pas.  With
    `vme_vectored_ints' the segment (0x40 bytes) holds VME_$USER_VEC
    alone, and VME_$SAVE is the VME_ASM segment's. }
  vme_$save: extern vme_$save_t;          { +0x00 }
  vme_$user_vec: extern array[vme_$first_user_int..vme_$max_user_int] of
                   vme_$int_vec_entry_t;  { +0x18 }
%if not vme_vectored_ints %then
  vme_$int_vec: extern array[0..vme_$max_level] of vme_$int_vec_entry_t;
                                          { +0x98 }
%endif

  { VME_CTL (map symbol of the I/O definitions): the VME bus adapter's
    register page, reached by its absolute address (another unit's
    object). }
  vme_ctl: extern vme_$ctl_t;

  { WIN (map symbol of the I/O definitions, with CALENDAR and TAPE at
    the same address): the disk and tape controller's register page. }
  win: extern vme_$dt_ctl_t;

{ VME_$UNDEF_INT - the handler of a VME vector with none defined: crash. }
function vme_$undef_int(handler_arg: univ_ptr): boolean;
  options(extern, val_param);

{ VME_$DEFINE_INT - define the handler of a VME interrupt level. }
procedure vme_$define_int(id: io_$int_id_t; handler: univ_ptr;
                          handler_arg: univ_ptr);
  options(extern, val_param);

{ VME_$INT - the VME bus's interrupt routine: find the interrupting level
  and call its handler.  With `vme_vectored_ints' the vector it was
  entered by, a word by value (the hand-written first-level handler
  pushes it), as MBUS_$INT's (mbus/mbus.ins.pas). }
%if vme_vectored_ints %then
procedure vme_$int(vector: integer); options(extern, val_param);
%else
procedure vme_$int; extern;
%endif

{ VME_$USER_INT - the handler of VME level 6: call the user interrupt's
  handler. }
function vme_$user_int(vector: univ_ptr): boolean;
  options(extern, val_param);

{ VME_$ERR_INT - the VME bus error interrupt routine. }
function vme_$err_int: boolean; extern;

{ VME_$SAVE_VME - save the VME bus adapter's state.  With
  `vme_vectored_ints' hand assembly (vme/sau6/vme_asm.s), called from
  the bus error and NMI handlers. }
procedure vme_$save_vme; extern;

{ GPU_$INTERRUPT (hand-written; declared in gpu/gpu.ins.pas): VME_$INIT
    stores it in level 4, and VME_$INT calls it with the bus's vector,
    one longword by value off the stack; a boolean result. }

{ VME_$INIT - install the VME bus's interrupt routines and its levels'
  handlers at boot.
  VME_$DEFINE_USERINT - define the handler of a VME user interrupt. }
procedure vme_$init; extern;
procedure vme_$define_userint(id: io_$int_id_t; handler: univ_ptr;
                              handler_arg: univ_ptr);
  options(extern, val_param);
