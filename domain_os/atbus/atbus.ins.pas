{ atbus/atbus.ins.pas - ATBUS_ (the AT bus) constants, types, variables
  and routine headings, for the Domain Pascal tree.

  The second ATBUS_ compilation unit (atbus/atbus.pas), with the part
  atbus_routines (base/config.ins.pas).  Apollo's customer insert files
  of SR10.2 declare nothing of ATBUS.  Include base/base.ins.pas and
  io/io.ins.pas before it.
}

const
  { The AT bus manager's status (the SR10.2 status-code database, "OS /
    pc/at bus manager": "(340001) undefined interrupt").
    ATBUS_$UNDEF_INT crashes with it, and the routines that take an
    interrupt id for an AT bus interrupt above 15. }
  status_$atbus_undefined_interrupt = 16#00340001;

  { The AT bus's interrupts, 0..15 (an id's vector word). }
  atbus_$max_irq = 15;

  { The system bus levels the SAU9's AT bus interrupts reach, 1..3
    (sysbus/sysbus.ins.pas): ATBUS_$INIT's loop count. }
  atbus_$n_levels = 3;

  { A level's interrupt while none is defined there: the SAU9's
    ATBUS_$INIT stores it, and the routines compare a level's
    interrupt with 15 unsigned. }
  atbus_$no_irq = 16#FFFF;

  { ATBUS_$XLATE_IOVA's two kinds of bus address: up to 16#400 the I/O
    ports, a page for each 8 of them from page 16#100; above, memory,
    1024 bytes to a page. }
  atbus_$io_port_limit = 16#400;
  atbus_$io_ports_per_page = 8;
  atbus_$io_first_page = 16#100;
  atbus_$page_size = 1024;

type
  { A system bus level of an AT bus interrupt: 1..3, and 0 in
    atbus/atbus.pas's table for an interrupt that has none.  The SAU9
    image tests a level with one unsigned compare of the level less 1
    with 2: `in_range' of a subrange from 1 (ref 4, "In_range"). }
  atbus_$level_t = 0..atbus_$n_levels;
  atbus_$int_level_t = 1..atbus_$n_levels;

  { An AT bus interrupt handler: the system bus's shape
    (sysbus/sysbus.ins.pas), one longword argument by value, a boolean
    result.  ATBUS_$UNDEF_INT is one. }
  atbus_$handler_t = ^function(handler_arg: univ_ptr): boolean;
    options(val_param);

  { An entry of ATBUS_$INT_VEC, 8 bytes: the handler and its argument. }
  atbus_$int_vec_entry_t = record
    handler: atbus_$handler_t;            { 0x00 }
    handler_arg: univ_ptr;                { 0x04 }
  end;

%if atbus_pics %then
  { An unsigned byte. }
  atbus_$byte_t = [byte] 0..255;

  { The two interrupt controllers (8259 class), from PIC1 (map symbol of
    the I/O definitions, without `$'; PIC2 is its +0x100): each a
    command port and a data port, the data port the interrupt mask
    once the controller is set up; the command port read after
    atbus_$read_irr gives the interrupts requested.  A mask and a
    request register as byte sets too, member k interrupt k of the
    controller.  `[device]': each access is a port access. }
  atbus_$pics_t = [device] record
    case integer of
      1: (m_cmd: atbus_$byte_t;           { 0x000 }
          m_imr: atbus_$byte_t;           { 0x001 }
          pad_002: array[16#002..16#0FF] of char;
          s_cmd: atbus_$byte_t;           { 0x100 }
          s_imr: atbus_$byte_t);          { 0x101 }
      2: (m_cmd_bits: [byte] set of 0..7; { 0x000 }
          m_imr_bits: [byte] set of 0..7; { 0x001 }
          pad_002b: array[16#002..16#0FF] of char;
          s_cmd_bits: [byte] set of 0..7; { 0x100 }
          s_imr_bits: [byte] set of 0..7); { 0x101 }
  end;

const
  { The controllers' command and set-up bytes: the end of interrupt;
    the request register's read; ICW1 (edge, cascade, ICW4 needed); the
    vectors from 16#A0 (master) and 16#A8 (slave); the master's slave on
    input 3 and the slave's id 3; ICW4 (8086 mode); every interrupt
    masked; the master's interrupts 0, 1 and 3 unmasked; and the
    slave's interrupt 0 unmasked. }
  atbus_$eoi = 16#20;
  atbus_$read_irr = 16#0A;
  atbus_$icw1 = 16#11;
  atbus_$m_vector_base = 16#A0;
  atbus_$s_vector_base = 16#A8;
  atbus_$m_cascade = 16#08;
  atbus_$s_cascade_id = 16#03;
  atbus_$icw4 = 16#01;
  atbus_$mask_all = 16#FF;
  atbus_$m_mask_run = 16#F4;
  atbus_$s_mask_run = 16#FE;

  { The vectors ATBUS_$INIT traps to ATBUS_$INT, 16#A0..16#AF. }
  atbus_$first_vector = 16#A0;

var
  pic1: extern atbus_$pics_t;

%endif
var
  { ATBUS_$INTLEV_VEC and ATBUS_$INT_VEC (map symbols, in the ATBUS_
    data block; defined in atbus/atbus.pas): a word for each AT bus
    interrupt, 0, 1, 3, 2, then 4..15; a handler and argument for each,
    ATBUS_$UNDEF_INT and nil in the image.  No routine of the SAU9 reads
    either; with `atbus_pics' ATBUS_$DEFINE_INT and the mask routines
    index by ATBUS_$INTLEV_VEC's word for the id (the controller input
    and the handler's entry), ATBUS_$INT by the vector's interrupt. }
  atbus_$intlev_vec: extern array[0..atbus_$max_irq] of integer;
  atbus_$int_vec: extern array[0..atbus_$max_irq] of atbus_$int_vec_entry_t;

%if atbus_pics %then
{ ATBUS_$INT - the AT bus's interrupt routine, trapped for the vectors
  16#A0..16#AF: the vector by value. }
procedure atbus_$int(vector: integer);
  options(extern, val_param);

%endif
{ ATBUS_$UNDEF_INT - the handler of an AT bus interrupt with none
  defined: crash.  Of atbus_$handler_t's type. }
function atbus_$undef_int(handler_arg: univ_ptr): boolean;
  options(extern, val_param);

{ ATBUS_$DEFINE_INT, ATBUS_$ENABLE_DEVICE, ATBUS_$DISABLE_DEVICE,
  ATBUS_$DEVICE_INTERRUPTING, ATBUS_$CLEAR_PENDING, ATBUS_$XLATE_IOVA,
  ATBUS_$INIT: IO_$BUS_EPV entry 3 (the AT bus) holds their addresses
  (io/io.pas); each heading is the type of its io_$bus_epv_t field.
  The id's vector word is the AT bus interrupt. }
procedure atbus_$define_int(id: io_$int_id_t; handler: univ_ptr;
                            handler_arg: univ_ptr);
  options(extern, val_param);
procedure atbus_$enable_device(id: io_$int_id_t);
  options(extern, val_param);
procedure atbus_$disable_device(id: io_$int_id_t);
  options(extern, val_param);
function atbus_$device_interrupting(id: io_$int_id_t): boolean;
  options(extern, val_param);
procedure atbus_$clear_pending(id: io_$int_id_t);
  options(extern, val_param);
function atbus_$xlate_iova(bus_addr: linteger): integer32;
  options(extern, val_param);
procedure atbus_$init; extern;
