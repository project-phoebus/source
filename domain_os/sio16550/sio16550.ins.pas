{ sio16550/sio16550.ins.pas - SIO16550_ (the 16550 UART driver) types,
  constants and routine headings, for the Domain Pascal tree.

  The driver is the SIO_IO module of the SAUs with `sio16550_lines'
  (base/config.ins.pas; sio16550/sio16550.pas).  The OS_TERM_INIT module
  reaches its records too (term/os_term_init.pas: KBD_$RESET, SIO_$INIT,
  TERM_$PCHIST_ENABLE).  Include base/base.ins.pas, ec/ec.ins.pas,
  time/time.ins.pas, io/io.ins.pas and sio/sio.ins.pas before it.
}

type
  { The UART's eight registers, a device (ref 3.15.3), one byte each at
    a 4-byte stride.  A register read as one thing and written as
    another at the same offset has both names; with the divisor latch
    selected (the line control's dlab) rbr_thr and ier are the divisor's
    low and high bytes. }
  sio16550_$regs_t = [device] record
    rbr_thr: char;                        { 0x00: receive buffer /
                                            transmit holding }
    unused_01: char;
    unused_02: char;
    unused_03: char;
    ier: char;                            { 0x04: interrupt enable }
    unused_05: char;
    unused_06: char;
    unused_07: char;
    iir_fcr: char;                        { 0x08: interrupt
                                            identification / FIFO
                                            control }
    unused_09: char;
    unused_0a: char;
    unused_0b: char;
    lcr: char;                            { 0x0C: line control }
    unused_0d: char;
    unused_0e: char;
    unused_0f: char;
    mcr: char;                            { 0x10: modem control }
    unused_11: char;
    unused_12: char;
    unused_13: char;
    lsr: char;                            { 0x14: line status }
    unused_15: char;
    unused_16: char;
    unused_17: char;
    msr: char;                            { 0x18: modem status }
    unused_19: char;
    unused_1a: char;
    unused_1b: char;
    scr: char;                            { 0x1C: scratch }
    unused_1d: char;
    unused_1e: char;
    unused_1f: char;
  end;
  sio16550_$regs_ptr_t = ^sio16550_$regs_t;

  { A register's byte as a packed record (ref 3.10.7: the 8-bit set at
    the record's first byte, member k its bit k; the fields from the
    byte's most significant bit; 16 bits in all), the form of
    sio2681/sio2681.ins.pas sio2681_$int_bits_t: the char arm for the
    register's move, the set arm for its bits, and the third arm for
    bits 3..1, the interrupt identification's code and the line status's
    error bits (overrun, parity, framing). }
  sio16550_$bits_t = packed record
    case integer of
      1: (c: char);                       { the byte }
      2: (s: set of 0..7);                { its members }
      3: (upper: 0..15;                   { bits 7..4 }
          code: 0..7;                     { bits 3..1 }
          low: boolean);                  { bit 0 }
  end;

  { The line control register the same way: the divisor latch access,
    the break, stick parity, even parity, parity enable, the second stop
    bit and the character length code (5 to 8 bits: 0 to 3). }
  sio16550_$lcr_t = packed record
    case integer of
      1: (c: char);
      2: (dlab: boolean;                  { bit 7 }
          brk: boolean;                   { bit 6 }
          stick: boolean;                 { bit 5 }
          eps: boolean;                   { bit 4 }
          pen: boolean;                   { bit 3 }
          stb: boolean;                   { bit 2 }
          wls: 0..3);                     { bits 1..0 }
  end;

  { The modem control register: the loop, the two outputs, RTS and DTR. }
  sio16550_$mcr_t = packed record
    case integer of
      1: (c: char);
      2: (unused: 0..7;                   { bits 7..5 }
          loop: boolean;                  { bit 4 }
          out2: boolean;                  { bit 3 }
          out1: boolean;                  { bit 2 }
          rts: boolean;                   { bit 1 }
          dtr: boolean);                  { bit 0 }
  end;

  { The divisor the baud rate gives, a word, written to the latch a byte
    at a time. }
  sio16550_$divisor_t = packed record
    case integer of
      1: (w: pinteger);
      2: (hi: char;                       { the high byte }
          lo: char);                      { the low byte }
  end;

const
  { Members of the line status: the transmit holding register is
    empty. }
  sio16550_$lsr_thre = 5;

  { Members of the interrupt identification: set when no interrupt is
    pending. }
  sio16550_$iir_no_int = 0;

  { The interrupt identification's codes (bits 3..1), the 16550's:
    modem status, transmit holding register empty, received data, line
    status, character timeout. }
  sio16550_$int_modem = 0;
  sio16550_$int_thre = 1;
  sio16550_$int_rda = 2;
  sio16550_$int_rls = 3;
  sio16550_$int_timeout = 6;

  { Members of the interrupt enable: received data, transmit holding
    register empty, line status, modem status. }
  sio16550_$ier_rda = 0;
  sio16550_$ier_thre = 1;
  sio16550_$ier_rls = 2;
  sio16550_$ier_modem = 3;

  { Members of the modem status: the CTS change, the DCD change, CTS,
    DCD. }
  sio16550_$msr_dcts = 0;
  sio16550_$msr_ddcd = 3;
  sio16550_$msr_cts = 4;
  sio16550_$msr_dcd = 7;

  { The driver's ports, 0 to 3 (SIO0_DCTE..SIO3_DCTE). }
  sio16550_$max_port = 3;

type
  { The channel record, 16 bytes (SIO16550_$INIT indexes the driver's
    four by the port, 16 apart).  sio_desc is the SIO descriptor
    SIO_$INIT hands back; line_flags the members SIO16550_$INQ_LINE adds
    to the parameter block's first flags; flags the PC-history word
    SIO16550_$INT tests before PCHIST_$INTERRUPT (TERM_$PCHIST_ENABLE
    stores it); chan_flags a set whose member 0 SIO16550_$SET_LINE
    clears.  SIO16550_$INIT clears the last three. }
  sio16550_$chan_t = record
    regs: sio16550_$regs_ptr_t;           { 0x00 }
    sio_desc: sio_$desc_ptr_t;            { 0x04 }
    line_flags: sio_$flags_t;             { 0x08 }
    flags: integer;                       { 0x0C }
    chan_flags: sio_$state_t;             { 0x0E }
  end;
  sio16550_$chan_ptr_t = ^sio16550_$chan_t;

  { A port's I/O descriptor, which its DCTE's disk_dinit points at
    (io/io.ins.pas io_$acquire_rec_t): the registers at csr.va, the
    interrupt at int.id. }
  sio16550_$io_desc_ptr_t = ^io_$acquire_rec_t;

  { The driver table SIO16550_$INIT passes SIO_$INIT, 0x28 bytes: the
    driver group of sio_$vtable_t (sio/sio.ins.pas) and a last longword,
    the characters 'sio' and a zero, which nothing reads. }
  sio16550_$vtable_t = record
    unused_00: array[1..5] of univ_ptr;   { 0x00 }
    driver: sio_$driver_t;                { 0x14 }
    name: array[1..4] of char;            { 0x24 }
  end;

{ Routine headings, in map order: WIRED_PROC (SIO16550_$XMIT, _$INT,
  _$SET_LINE, _$SET_BREAK), OS_INIT_PROC (SIO16550_$INIT), PROCEDURE$
  (SIO16550_$INQ_LINE).  The driver entries take the channel record by
  address and the rest by value, as the SIO descriptor's entries are
  called (sio/sio.ins.pas sio_$output_char_t and the others):
  `val_param'. }

{ SIO16550_$XMIT - send a character on a channel. }
procedure sio16550_$xmit(in chan: sio16550_$chan_t; ch: char);
  options(extern, val_param);

{ SIO16550_$INT - service a 16550's interrupt.  SYSBUS_$INT calls it with
  the channel record's address as the handler's longword argument and
  reads the boolean result. }
function sio16550_$int(arg: integer32): boolean;
  options(extern, val_param);

{ SIO16550_$SET_LINE - set a channel's line parameters. }
procedure sio16550_$set_line(var chan: sio16550_$chan_t;
                             in params: sio_$params_t;
                             change_mask: sio_$flags_t;
                             out status: status_$t);
  options(extern, val_param);

{ SIO16550_$SET_BREAK - start or stop a break on a channel. }
procedure sio16550_$set_break(in chan: sio16550_$chan_t; enable: boolean);
  options(extern, val_param);

{ SIO16550_$INIT - initialize a 16550 port: its DCTE's initialization
  routine (io/io.ins.pas dcte_init_proc_t). }
function sio16550_$init(var dcte: dcte_t): integer32; extern;

{ SIO16550_$INQ_LINE - report a channel's modem inputs. }
procedure sio16550_$inq_line(in chan: sio16550_$chan_t;
                             in out params: sio_$params_t;
                             mask: sio_$flags_t; out status: status_$t);
  options(extern, val_param);
