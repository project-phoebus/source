{ mbus/mbus.ins.pas - MBUS_ (Multibus) constants, types, variables and
  routine headings, for the Domain Pascal tree.

  The MBUS_ module (mbus/mbus.pas) is the Multibus's interrupt vector
  and its set-up, on the SAUs whose machines have a Multibus (the part
  mbus_bus, base/config.ins.pas).  On the SAU5 the Multibus is reached
  through the VME bus adapter: the VME_ module's interrupt routine
  dispatches the Multibus's interrupts through MBUS_$INT_VEC, and
  MBUS_$ENABLE_DEV and MBUS_$DISABLE_DEV are in the VME_ module.

  Apollo's customer insert files of SR10.2 declare nothing of MBUS.
  Include base/base.ins.pas, misc/crash_system.ins.pas and
  io/io.ins.pas (io_$int_id_t) before it.
}

const
  { The status MBUS_$UNDEF_INT and MBUS_$DEFINE_INT crash with: module
    0, code 16#2A, which has no text in the SR10.2 status-code database
    (the VME bus manager's is "(270001) undefined vme interrupt").
    Passed to CRASH_SYSTEM's 4-byte univ formal, its cell is a longword
    (ref 3.2.3, 5.3.3). }
  status_$mbus_undefined_interrupt = 16#2A;

  { The highest Multibus interrupt level: MBUS_$DEFINE_INT's bound, and
    MBUS_$INT_VEC's (0x80 bytes, sixteen 8-byte entries). }
  mbus_$max_level = 15;

  { With the polled adapter (`mbus_polled_adapter'): the processor's
    vector MBUS_$INIT gives MBUS_$INT (IO_$TRAP), the level-4
    autovector, and the distance from a level's bit in the adapter's
    register at +2 to its pending bit (levels 0..7). }
  mbus_$int_vector = 16#1C;
  mbus_$pending_bits = 8;

  { With the vectored adapter (`mbus_vectored_adapter'): the first of the
    levels' vectors (level 0's; the level is the vector less it), the
    levels MBUS_$INIT traps, and what MBUS_$INT adds to the level for the
    adapter's acknowledge register. }
  mbus_$first_vector = 16#B0;
  mbus_$vectored_levels = 8;
  mbus_$ack_base = 16#60;

type
  { A Multibus interrupt handler: called with the argument
    MBUS_$DEFINE_INT stored beside it, by value; its boolean says
    whether the interrupt was handled (VME_$INT enables the level again
    when it was).  MBUS_$UNDEF_INT is one. }
  mbus_$handler_t = ^function(handler_arg: univ_ptr): boolean;
    options(val_param);

  { An entry of MBUS_$INT_VEC, 8 bytes (MBUS_$DEFINE_INT indexes it by
    the level shifted left 3): the handler and its argument. }
  mbus_$int_vec_entry_t = record
    handler: mbus_$handler_t;             { 0x00 }
    handler_arg: univ_ptr;                { 0x04 }
  end;

  { The Multibus adapter's registers at PBU_CTL, as the MBUS_ and VME_
    routines reach them: three words.  word_00 MBUS_$INIT writes back
    as the value its probe read with bits 16#213 set; int_enable, one
    bit per interrupt level (MBUS_$ENABLE_DEV adds a level,
    MBUS_$DISABLE_DEV removes it, VME_$INT removes the interrupting
    level and adds it again when its handler has handled it; on the
    SAU3 the bits 8..15 are levels 0..7 pending, which MBUS_$INT
    polls), cleared by MBUS_$INIT; word_04 set by MBUS_$INIT.  `[device]': MBUS_$INIT
    clears int_enable with a store of the constant 0, not a clear (the
    two never-merged word stores too).  The record's size past 6 is not
    seen. }
  mbus_$ctl_t = [device] record
    word_00: integer;                     { 0x00 }
    int_enable: set of 0..15;             { 0x02 }
    word_04: integer;                     { 0x04 }
%if mbus_vectored_adapter %then
    word_06: integer;                     { 0x06: the PNA's printer
                                            port's control (LPR_$INIT) }
    unused_08: array[4..63] of integer;   { 0x08 }
    ack: integer;                         { 0x80: the level being served,
                                            plus mbus_$ack_base; MBUS_$INIT
                                            probes it }
    int_mask: set of 0..15;               { 0x82: a level's bit set while
                                            its handler runs; MBUS_$INIT
                                            writes three words to it }
%endif
  end;

var
  { The module's data block, the map's MBUS_ data segment in
    WIRED_DATA (0x84 bytes; map symbols at +0x00, +0x80, +0x82), all
    zero in the image.  Defined in mbus/mbus.pas. }
  mbus_$int_vec: extern array[0..mbus_$max_level] of mbus_$int_vec_entry_t;
                                          { +0x00 }
  mbus_$high_ok: extern boolean;          { +0x80 }
  mbus_$present: extern boolean;          { +0x82 }

  { PBU_CTL (map symbol of the I/O definitions, with no `$'): the
    Multibus adapter's register page, reached by its absolute address
    (another unit's object).  Its users are the MBUS_ and VME_ modules
    (and the SAU5's PBU, not translated). }
  pbu_ctl: extern mbus_$ctl_t;

{ MBUS_$UNDEF_INT (mbus/undef_int.pas): the handler of a level with none
  defined, of mbus_$handler_t's type. }
function mbus_$undef_int(handler_arg: univ_ptr): boolean;
  options(extern, val_param);

{ MBUS_$INIT, MBUS_$DEFINE_INT, MBUS_$ENABLE_DEV, MBUS_$DISABLE_DEV:
  IO_$BUS_EPV's entry 2 (the Multibus) holds their addresses, as init,
  define_int, enable_device and disable_device (io/io.pas); each heading
  is the type of its io_$bus_epv_t field.  The id's vector word is the
  interrupt level. }
procedure mbus_$init; extern;

{ MBUS_$INT (mbus/int.pas, `mbus_polled_adapter'): the routine IO_$TRAP
  installs for the Multibus's vector; no arguments.  With
  `mbus_vectored_adapter' the vector it was entered by, a word by value
  (the hand-written first-level handler pushes it). }
%if mbus_vectored_adapter %then
procedure mbus_$int(vector: integer); options(extern, val_param);
%else
procedure mbus_$int; extern;
%endif
procedure mbus_$define_int(id: io_$int_id_t; handler: univ_ptr;
                           handler_arg: univ_ptr);
  options(extern, val_param);
procedure mbus_$enable_dev(id: io_$int_id_t);
  options(extern, val_param);
procedure mbus_$disable_dev(id: io_$int_id_t);
  options(extern, val_param);
