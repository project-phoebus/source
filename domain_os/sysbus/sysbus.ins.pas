{ sysbus/sysbus.ins.pas - SYSBUS_ constants, types, variables and routine
  headings, for the Domain Pascal tree.

  The SYSBUS_ routines are in the ATBUS_ module (sysbus/atbus_.pas,
  sysbus/README.md).  Apollo's customer insert files of SR10.2
  declare nothing of SYSBUS.  Include base/base.ins.pas and
  io/io.ins.pas (io_$int_id_t; it needs ml/ml.ins.pas) before it. }

const
  { The System Bus Manager's statuses; the SR10.2 status-code database:
    "OS / System Bus Manager", "(3e0001) undefined interrupt" and
    "(3e0002) unknown interrupt ID".  SYSBUS_$UNDEF_INT crashes with the
    first; SYSBUS_$DEFINE_INT and, with `sysbus_int_vec', the routines
    that take a vector number with the second. }
  status_$sysbus_undefined_interrupt = 16#003E0001;
  status_$sysbus_unknown_interrupt_id = 16#003E0002;

  { The system bus's interrupt levels, with `sysbus_int_vec' (the
    SAU9's form): sixteen levels, 0..15, delivered on the vectors 16#A0
    .. 16#AF (SYSBUS_$INIT traps them, and a vector less 16#A0 is its
    level); levels 0..7 are the bits of the controller's low registers,
    8..15 those of its high ones.  With `sysbus_vectors_90': 32 levels,
    the vectors 16#90..16#9F and a second range, 16#F0..16#FF, whose
    vectors are moved down by the gap between the ranges
    (sysbus_$first_vector_2 - sysbus_$last_vector) before the first
    vector is subtracted.  With `sysbus_vectors_88': the same with the
    vectors 16#88..16#9F and 16#F0..16#F7, so 16#F0 is level 23, as
    16#9F is; the vector table has 32 levels. }
%if sysbus_vectors_90 %then
  sysbus_$first_vector = 16#90;
  sysbus_$last_vector = 16#9F;
  sysbus_$first_vector_2 = 16#F0;
  sysbus_$last_vector_2 = 16#FF;
  sysbus_$max_level = 31;
%elseif sysbus_vectors_88 %then
  sysbus_$first_vector = 16#88;
  sysbus_$last_vector = 16#9F;
  sysbus_$first_vector_2 = 16#F0;
  sysbus_$last_vector_2 = 16#F7;
  sysbus_$max_level = 31;

  { The highest entry of SYSBUS_$DUP_VEC (8 entries). }
  sysbus_$max_dup = 7;
%else
  sysbus_$first_vector = 16#A0;
  sysbus_$last_vector = 16#AF;
  sysbus_$max_level = 15;
%endif
  sysbus_$first_hi_level = 8;

type
  { A system bus level, 0..15 (0..31 with `sysbus_vectors_90' or
    `sysbus_vectors_88').  The
    SAU9 image compares it with 8 unsigned, the form of a non-negative
    subrange. }
  sysbus_$level_t = 0..sysbus_$max_level;

  { A level's interrupt handler: called by SYSBUS_$INT with the argument
    stored beside it, one longword by value; true when the level is to
    be enabled again (SYSBUS_$INT tests the result's sign).  The shape
    of the Multibus's (mbus/mbus.ins.pas).  SYSBUS_$UNDEF_INT is one. }
  sysbus_$handler_t = ^function(handler_arg: univ_ptr): boolean;
    options(val_param);

  { An entry of SYSBUS_$INT_VEC, 8 bytes: the handler and its argument
    (the routines index the vector by the level scaled by 8).  With
    `sysbus_vectors_88' 12 bytes (scaled by 12): dup_slot is the entry
    of SYSBUS_$DUP_VEC that holds the level's second handler, which
    SYSBUS_$DEFINE_INT stores when it gives the level one; the
    SYSBUS_$DUP_VEC entries are of the same type, their dup_slot
    unused. }
  sysbus_$int_vec_entry_t = record
    handler: sysbus_$handler_t;           { 0x00 }
    handler_arg: univ_ptr;                { 0x04 }
%if sysbus_vectors_88 %then
    dup_slot: integer32;                  { 0x08 }
%endif
  end;

  { A one-byte set (ref 3.15.5): the levels of one of the controller's
    byte registers, member k level k (low registers) or 8 + k (high
    ones). }
  sysbus_$level_bits_t = [byte] set of 0..7;

  { The utility interrupt controller's registers at UTIL_PIC (below),
    with `util_pic', one byte at the start of each longword.
    - enable_hi, enable_lo: a level's bit set lets it interrupt
      (SYSBUS_$ENABLE_DEVICE sets it, SYSBUS_$DISABLE_DEVICE clears it,
      SYSBUS_$INIT clears them all);
    - pending_hi, pending_lo: read, a level's bit is set while it is
      interrupting (SYSBUS_$DEVICE_INTERRUPTING); written, the bits
      written as 1 are cleared (SYSBUS_$CLEAR_PENDING writes one level's,
      SYSBUS_$INIT all);
    - vector_base: SYSBUS_$INIT writes 16#A0, the vector of level 0.
    `[device]' (ref 3.15.3): the SAU9 image stores zero and all-ones
    here with `move' immediates, not `clr'/`st'. }
  sysbus_$util_pic_t = [device] record
    enable_hi: sysbus_$level_bits_t;      { 0x00: levels 8..15 }
    unused_01: char;                      { 0x01 }
    unused_02: integer;                   { 0x02 }
    enable_lo: sysbus_$level_bits_t;      { 0x04: levels 0..7 }
    unused_05: char;                      { 0x05 }
    unused_06: integer;                   { 0x06 }
    pending_hi: sysbus_$level_bits_t;     { 0x08: levels 8..15 }
    unused_09: char;                      { 0x09 }
    unused_0a: integer;                   { 0x0A }
    pending_lo: sysbus_$level_bits_t;     { 0x0C: levels 0..7 }
    unused_0d: char;                      { 0x0D }
    unused_0e: integer;                   { 0x0E }
    unused_10: integer32;                 { 0x10 }
    unused_14: integer32;                 { 0x14 }
    vector_base: [byte] 0..255;           { 0x18 }
  end;

  { The registers at UTIL_PIO (below) that SYSBUS_$INIT writes, one byte
    at +0x4 (16#10) and one at +0x8 (16#CF).  What they control is not
    known; nothing else in the SAU9 image addresses them. }
  sysbus_$util_pio_t = [device] record
    unused_00: integer32;                 { 0x00 }
    reg_04: [byte] 0..255;                { 0x04 }
    unused_05: char;                      { 0x05 }
    unused_06: integer;                   { 0x06 }
    reg_08: [byte] 0..255;                { 0x08 }
  end;

var
  { SYSBUS_$INT_VEC (map symbol, the ATBUS_ data block's start with
    `sysbus_int_vec'): a handler and argument per level, all zero in the
    image; SYSBUS_$INIT sets every handler to SYSBUS_$UNDEF_INT.
    Defined in sysbus/atbus_.pas. }
  sysbus_$int_vec: extern array[0..sysbus_$max_level] of
                     sysbus_$int_vec_entry_t;
%if sysbus_vectors_88 %then

  { SYSBUS_$DUP_VEC (map symbol, the block's start with
    `sysbus_vectors_88', before SYSBUS_$INT_VEC): the levels' second
    handlers and their arguments, taken in turn by SYSBUS_$DEFINE_INT;
    all zero in the image.  Defined in sysbus/atbus_.pas. }
  sysbus_$dup_vec: extern array[0..sysbus_$max_dup] of
                     sysbus_$int_vec_entry_t;
%endif

  { UTIL_PIC and UTIL_PIO: map symbols of the SAU9's I/O definitions,
    another unit's variables. }
  util_pic: extern sysbus_$util_pic_t;
  util_pio: extern sysbus_$util_pio_t;

{ SYSBUS_$INT - dispatch a system bus interrupt to its level's handler.
  The hand-written first-level handler that IO_$TRAP installs calls it
  with the vector number pushed as a word: by value. }
procedure sysbus_$int(vector: integer); options(extern, val_param);

{ SYSBUS_$UNDEF_INT - the handler of a level with none defined: crash.
  Of sysbus_$handler_t's type. }
function sysbus_$undef_int(handler_arg: univ_ptr): boolean;
  options(extern, val_param);

{ SYSBUS_$INIT - install the system bus's interrupt routines. }
procedure sysbus_$init; extern;

{ SYSBUS_$DEFINE_INT - define a system bus interrupt's handler.  IO_$BUS_EPV
  entry 4's define_int; ATBUS_$DEFINE_INT and others call it too. }
procedure sysbus_$define_int(id: io_$int_id_t; handler: univ_ptr;
                             handler_arg: univ_ptr);
  options(extern, val_param);

{ SYSBUS_$ENABLE_DEVICE, SYSBUS_$DISABLE_DEVICE,
  SYSBUS_$DEVICE_INTERRUPTING, SYSBUS_$CLEAR_PENDING (with `util_pic'):
  IO_$BUS_EPV entry 4's routines of those names, each heading the type
  of its io_$bus_epv_t field; TIMER_$INIT and the ATBUS_$ routines call
  them directly, the id as a longword. }
procedure sysbus_$enable_device(id: io_$int_id_t);
  options(extern, val_param);
procedure sysbus_$disable_device(id: io_$int_id_t);
  options(extern, val_param);
function sysbus_$device_interrupting(id: io_$int_id_t): boolean;
  options(extern, val_param);
procedure sysbus_$clear_pending(id: io_$int_id_t);
  options(extern, val_param);
