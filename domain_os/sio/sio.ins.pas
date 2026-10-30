{ sio/sio.ins.pas - SIO_$ (serial I/O) constants, types and routine
  headings, for the Domain Pascal tree.

  What the Pascal files use.  The statuses' texts are the SR10.2 status
  database's ("OS / serial I/O", `node stcode.js stcode.db.10.2').

  Include base/base.ins.pas, ec/ec.ins.pas and time/time.ins.pas before
  it (sio_$desc_t's eventcount and queue element). }

const
  status_$sio_framing_error = 16#00360004;  { character framing error }
  status_$sio_parity_error  = 16#00360005;  { character parity error }
  status_$sio_code_0b       = 16#0036000B;  { not in the SR10.2 database }

  { 16#00360001, "invalid option" (OS / serial I/O, stcode.db.10.2).
    SIO6509_$SET_LINE stores it (sio6509/set_line.pas). }
  status_$sio_invalid_option = 16#00360001;

  { 16#00360008, "incompatible speed request" (stcode.db.10.2).
    SIO2681_$SET_LINE stores it (sio2681/set_line.pas). }
  status_$sio_incompatible_speed = 16#00360008;

  { The other statuses SIO stores (OS / serial I/O, stcode.db.10.2):
    SIO_$K_SET_PARAM's invalid value; SIO_$I_ERR's results for the
    pending conditions; SIO_$K_SIGNAL_WAIT's quit. }
  status_$sio_invalid_param = 16#00360002;     { illegal parameter value }
  status_$sio_dcd_changed = 16#00360006;       { data carrier detect (dcd)
                                                 changed }
  status_$sio_cts_changed = 16#00360007;       { clear to send (cts)
                                                 changed }
  status_$sio_input_overrun = 16#00360009;     { input buffer overrun }
  status_$sio_quit_while_waiting = 16#0036000A;  { quit while waiting }

  { The parameter block's codes for the parity, the character size and
    the stop bits: Apollo's, from the customer sio.ins.pas (`sio_$no_parity
    = 0; sio_$odd_parity = 1; sio_$even_parity = 3', `sio_$5bpc = 0;
    sio_$6bpc = 2; sio_$7bpc = 1; sio_$8bpc = 3', `sio_$stop_1 = 1;
    sio_$stop_1_point_5 = 2; sio_$stop_2 = 3').  SIO2681_$SET_LINE
    dispatches on them (sio2681/set_line.pas): the arms set the 2681's
    MR1 parity bits, its bits-per-character code (5, 6, 7, 8 bits: 0, 1,
    2, 3, so sio_$7bpc = 1 gives the code 2) and its MR2 stop-bit code
    (7, 8, 15). }
  sio_$no_parity = 0;
  sio_$odd_parity = 1;
  sio_$even_parity = 3;
  sio_$5bpc = 0;
  sio_$6bpc = 2;
  sio_$7bpc = 1;
  sio_$8bpc = 3;
  sio_$stop_1 = 1;
  sio_$stop_1_point_5 = 2;
  sio_$stop_2 = 3;

type
  { The two rates of the parameter block's baud_rate, one word each:
    TERM_$CONTROL stores them one at a time, and TERM_$INQUIRE reads the
    second: two words, the layout of sio2681/sio2681.ins.pas's
    sio2681_$rates_t (tx, rx), whose names this repeats;
    SIO2681_$SET_LINE reads the field whole into such a record
    (sio2681/set_line.pas, a type transfer of the same size).  An
    integer32 cannot be written by halves (ref 4, "Type Transfer
    Functions": not an lvalue). }
  sio_$rates_t = record
    tx: pinteger;                         { 0x00 }
    rx: pinteger;                         { 0x02 }
  end;

  { The flag longwords of the parameter block, sets of 32 members
    (member k is bit k).  SIO2681_$SET_LINE tests members of both in
    memory, SIO2681_$INQ_LINE sets and clears members of flags1, tests
    member 6 of flags2 and unions a channel's set into flags1: the forms
    of the set operators, the byte that holds the member at the
    longword's last byte.  SIO6509_$INQ_LINE's or-immediate is
    `+ [1, 2]'. }
  sio_$flags_t = set of 0..31;

  { The parameter block's parity, character size and stop bits, Apollo's
    subranges (the customer sio.ins.pas: `sio_$stop_bit_t = 1..3;
    sio_$parity_t = 0..3; sio_$word_size_t = 0..3').  Each takes a word
    (ref 3.8.1).  SIO_$K_SET_PARAM checks each against its range in the
    form of `in_range' (ref p. 4-104): the parity and the character size
    by one unsigned compare with the last value, the stop bits by the
    first value subtracted and an unsigned compare: the range checks of
    0..3 and 1..3, which an `integer' field would not have.  The fields'
    users (term/control.pas, term/inquire.pas, sio2681/set_line.pas,
    term/os_term_init.pas's initializers) store and compare the values
    the constants above name, all in range. }
  sio_$stop_bit_t = 1..3;
  sio_$parity_t = 0..3;
  sio_$word_size_t = 0..3;

  { The line parameter block, 0x16 bytes.  SIO6509_$INQ_LINE sets
    members 1 and 2 of the first longword; the flags are sets
    (sio_$flags_t above, SIO2681's evidence).  SIO2681_$SET_LINE copies
    baud_rate whole into a record of two words and dispatches on parity,
    char_size and stop_bits as words.  break_mask is a set too:
    TERM_$CONTROL builds it as one in a register ([], [0], + [1], + [3],
    + [4]), and TERM_$INQUIRE tests its members on the low byte;
    baud_rate is sio_$rates_t (above).  No other Pascal file names
    either field.  Apollo's customer sio.ins.pas has no such record (its
    sio_$value_t is the user interface's). }
  sio_$params_t = record
    flags1: sio_$flags_t;                 { 0x00 }
    flags2: sio_$flags_t;                 { 0x04 }
    break_mask: sio_$flags_t;             { 0x08: a set, above }
    baud_rate: sio_$rates_t;              { 0x0C: two words, above }
    char_size: sio_$word_size_t;          { 0x10 }
    stop_bits: sio_$stop_bit_t;           { 0x12 }
    parity: sio_$parity_t;                { 0x14 }
  end;

  { The descriptor's state word, a set of 16 members, all in the low
    byte.  The routines set, clear and test its members on the word's
    low byte, member 7 by the byte's sign, and work on the whole word for
    several members: the set forms, member k bit k.  The members:
    transmit active (0), CTS blocked (1), inhibited (2), break active
    (3), delay active (4), defer inhibit (5), defer pending (6), defer
    complete (7). }
  sio_$state_t = set of 0..15;

  { The transmit buffer a descriptor points at: three words, then the
    characters from 1 (SIO_$I_TSTART compares the head against the tail,
    reads element head at 5 + head, wraps the head at the size).  The
    layout of tty/tty.ins.pas tty_$cbuf_t (the serial lines' buffer is
    the TTY descriptor's output buffer, TERM_$INIT and SIO_$INIT pass
    `addr(tty_descs[n].output)') and of kbd's ring (kbd_descs[1].txbuf,
    kbd_$ring_size characters); declared here because this file comes
    before tty/tty.ins.pas.  The data bound is tty_$buf_size's 256 (the
    largest), the names tty_$cbuf_t's. }
  sio_$txbuf_t = record
    head: integer;                        { 0x00: consumer position }
    tail: integer;                        { 0x02: producer position }
    size: integer;                        { 0x04 }
    data: array[1..256] of char;          { 0x06 }
  end;
  sio_$txbuf_ptr_t = ^sio_$txbuf_t;

  { The descriptor's handlers and its driver's entries, each called by
    value through its field: SIO_$I_RCV's (the owner, and the owner and
    a character), SIO_$I_TSTART's (the context and a character),
    SIO_$K_SET_PARAM's (the context by value, the block by address, the
    mask by value, the status), SIO_$K_INQ_PARAM's (the same for
    inq_params), sio_$set_break's (the context and a boolean).  So
    `val_param' routine types (ref 3.13.3; the drivers' SIO2681_$XMIT,
    _SET_LINE, _INQ_LINE, _SET_BREAK and SIO6509_$XMIT are `val_param'
    with the channel record by address, sio2681/sio2681.ins.pas,
    sio6509/sio6509.ins.pas; the handlers TTY_$I_RCV, KBD_$RCV and the
    others take their descriptor by address, the owner's value).  The
    set_params entry's block is `in' (SIO2681_$SET_LINE's), inq_params'
    `in out' (SIO2681_$INQ_LINE's). }
  sio_$owner_proc_t = ^procedure(owner: univ_ptr); options(val_param);
  sio_$rcv_proc_t = ^procedure(owner: univ_ptr; ch: char);
    options(val_param);
  sio_$output_char_t = ^procedure(context: univ_ptr; ch: char);
    options(val_param);
  sio_$set_params_t = ^procedure(context: univ_ptr;
                                 in params: sio_$params_t;
                                 mask: sio_$flags_t;
                                 out status: status_$t);
    options(val_param);
  sio_$inq_params_t = ^procedure(context: univ_ptr;
                                 in out params: sio_$params_t;
                                 mask: sio_$flags_t;
                                 out status: status_$t);
    options(val_param);
  sio_$set_break_t = ^procedure(context: univ_ptr; enable: boolean);
    options(val_param);

  { The two groups of four the initializer copies whole: sio_$init_desc
    copies 16 bytes from its handler block into +0x28 and 16 from its
    driver table's +0x14 into +0x3C (sio/init_desc.pas): record
    assignments (a block copy through two address registers), not field
    stores, which would carry the fields' displacements.  So the
    descriptor holds these two records.  The fields are univ_ptr, as
    term/term.ins.pas dtte_t's and term/os_term_init.pas's handler
    blocks, which TERM_$SET_REAL_LINE_DISCIPLINE stores into them
    (term/set_real_line_discipline.pas) and from which the initializers
    copy; each call converts its field to the routine type above, as
    mac_os/close.pas converts its driver's entries. }
  sio_$handlers_t = record
    rcv_handler: univ_ptr;                { 0x00 (desc 0x28): an
                                            sio_$rcv_proc_t }
    drain_handler: univ_ptr;              { 0x04 (desc 0x2C): an
                                            sio_$owner_proc_t }
    dcd_handler: univ_ptr;                { 0x08 (desc 0x30): an
                                            sio_$owner_proc_t }
    special_rcv: univ_ptr;                { 0x0C (desc 0x34): an
                                            sio_$owner_proc_t }
  end;
  sio_$driver_t = record
    output_char: univ_ptr;                { 0x00 (desc 0x3C): an
                                            sio_$output_char_t }
    set_params: univ_ptr;                 { 0x04 (desc 0x40): an
                                            sio_$set_params_t }
    inq_params: univ_ptr;                 { 0x08 (desc 0x44): an
                                            sio_$inq_params_t }
    set_break: univ_ptr;                  { 0x0C (desc 0x48): an
                                            sio_$set_break_t }
  end;

  { The SIO descriptor of a line, 0x78 bytes.  The OS_TERM_INIT module
    holds three of them (term/os_term_init.pas, sio_descs at +0xFF0,
    elements of 0x78 bytes), and TERM_$INIT stores into the params'
    baud_rate of one.  The queue element and the eventcount are their
    own types, time/time.ins.pas time_$queue_elem_t (SIO_$I_TSTART
    passes the element to TIME_$Q_ADD_CALLBACK's `var' element) and
    ec/ec.ins.pas ec_$eventcount_t (SIO_$I_INIT passes it to EC_$INIT;
    SIO_$I_CTS_CHANGE to EC_$ADVANCE_WITHOUT_DISPATCH;
    SIO_$K_SIGNAL_WAIT reads its value).  The handlers and the driver's
    entries are the two groups above; pending_int is a set (SIO_$I_RCV
    unions into it and tests member 5; SIO_$I_ERR's masks), the members
    parity 0, framing 1, overrun 2, dcd 3, cts 4, bit5 5; state is
    sio_$state_t (above); txbuf sio_$txbuf_ptr_t.  No other unit names a
    field but params. }
  sio_$desc_t = record
    context: univ_ptr;                    { 0x00: the driver's channel }
    owner: univ_ptr;                      { 0x04: the TTY or KBD
                                            descriptor }
    delay_qelem: time_$queue_elem_t;      { 0x08 }
    reserved_22: integer;                 { 0x22 }
    txbuf: sio_$txbuf_ptr_t;              { 0x24 }
    handlers: sio_$handlers_t;            { 0x28 }
    data_rcv: univ_ptr;                   { 0x38: an sio_$rcv_proc_t }
    driver: sio_$driver_t;                { 0x3C }
    params: sio_$params_t;                { 0x4C }
    reserved_62: integer;                 { 0x62 }
    pending_int: sio_$flags_t;            { 0x64 }
    ec: ec_$eventcount_t;                 { 0x68 }
    state: sio_$state_t;                  { 0x74 }
    reserved_76: integer;                 { 0x76 }
  end;
  sio_$desc_ptr_t = ^sio_$desc_t;
  sio_$desc_ptr_ptr_t = ^sio_$desc_ptr_t;

  { The driver table sio_$init_desc copies from: its entries 6..9, at
    +0x14, are the descriptor's driver group (above; TERM_$INIT's
    console_vtable and serial_vtable, term/init.pas, ten and nine
    entries, the first five zero).  The group's place is all the routine
    reads; the five longwords before it are stand-ins. }
  sio_$vtable_t = record
    unused_00: array[1..5] of univ_ptr;   { 0x00 }
    driver: sio_$driver_t;                { 0x14 }
  end;

  { The TTY descriptor's four handlers that sio_$init_line copies whole
    (sio/init_line.pas), from its line handler block's +8
    (term/os_term_init.pas term_$serial_line_handlers: SIO_$I_TSTART,
    _INHIBIT_XMIT, _INHIBIT_RCV, _ERR; term_$console_line_handlers:
    DTTY_$TSTART, 0, 0, 0): tty/tty.ins.pas tty_$desc_t's xmit_callback,
    xon_xoff_handler, flow_ctrl_handler and status_handler at
    0x2B4..0x2C3 as one record (see the TODO(pascal) in
    sio/init_line.pas).  The line handler block is two longwords and this
    group. }
  sio_$tty_handlers_t = record
    xmit_callback: univ_ptr;              { 0x00 (TTY desc 0x2B4) }
    xon_xoff_handler: univ_ptr;           { 0x04 (0x2B8) }
    flow_ctrl_handler: univ_ptr;          { 0x08 (0x2BC) }
    status_handler: univ_ptr;             { 0x0C (0x2C0) }
  end;
  sio_$tty_handlers_ptr_t = ^sio_$tty_handlers_t;
  sio_$line_handlers_t = record
    unused_00: univ_ptr;                  { 0x00 }
    unused_04: univ_ptr;                  { 0x04 }
    tty: sio_$tty_handlers_t;             { 0x08 }
  end;

{ Routine headings, in map order: the SIO module's WIRED_PROC segment,
  SIO_$INIT in OS_TERM_INIT's OS_INIT_PROC segment, SIO_$I_GET_DESC in
  OS_TERM's .TEXT segment, then the SIO module's .TEXT segment.  The
  bodies repeat the full headings (ref 7.3.4, Method 2): sio/sio.pas,
  and term/os_term_init.pas and term/os_term.pas for SIO_$INIT and
  SIO_$I_GET_DESC.  The SIO_$I_ routines take the descriptor as
  sio_$desc_ptr_t: the bodies reach its fields through it, and the
  callers' univ_ptr values are assignment compatible with it (ref 3.13:
  univ_ptr and any pointer type; sio2681/int.pas, set_break.pas,
  sio6509/rcv.pas; TERM's handler blocks take their addresses). }

{ SIO_$I_RCV - a character received on a serial line. }
procedure sio_$i_rcv(desc: sio_$desc_ptr_t; char_data: char;
                     error_flags: integer32);
  options(extern, val_param);

{ SIO_DELAY_RESTART - the end of a transmit delay. }
procedure sio_delay_restart(in arg: sio_$desc_ptr_ptr_t); extern;

{ SIO_$I_XMIT_DONE - a character has been sent on a serial line. }
function sio_$i_xmit_done(desc: sio_$desc_ptr_t): boolean;
  options(extern, val_param);

{ SIO_$I_CTS_CHANGE - the clear-to-send line of a serial line changed.
  SIO_$I_DCD_CHANGE - the data-carrier-detect line of a serial line
  changed. }
procedure sio_$i_cts_change(desc: sio_$desc_ptr_t; state: boolean);
  options(extern, val_param);
procedure sio_$i_dcd_change(desc: sio_$desc_ptr_t; state: boolean);
  options(extern, val_param);

{ SIO_$I_TSTART - start or continue the transmission of a serial line. }
procedure sio_$i_tstart(desc: sio_$desc_ptr_t);
  options(extern, val_param);

{ SIO_$I_INHIBIT_RCV - stop or resume a serial line's receiver.
  SIO_$I_INHIBIT_XMIT - stop or resume a serial line's transmitter. }
procedure sio_$i_inhibit_rcv(desc: sio_$desc_ptr_t; inhibit: boolean;
                             update_xmit: boolean);
  options(extern, val_param);
procedure sio_$i_inhibit_xmit(desc: sio_$desc_ptr_t; inhibit: boolean);
  options(extern, val_param);

{ SIO_$INIT - set up one serial port's terminal line. }
procedure sio_$init(port: integer; in context: univ univ_ptr;
                    in vtable: univ sio_$vtable_t;
                    out desc_ret: sio_$desc_ptr_t; crash: boolean;
                    out status: status_$t);
  options(extern, val_param);

{ SIO_$I_GET_DESC - the SIO descriptor of a terminal line. }
function sio_$i_get_desc(line: integer; out status: status_$t): integer32;
  options(extern, val_param, a0_return);

{ SIO_$I_ERR - take a serial line's pending condition as a status. }
function sio_$i_err(desc: sio_$desc_ptr_t; check_all: boolean): integer32;
  options(extern, val_param);

{ SIO_$I_INIT - reset a new SIO descriptor's state. }
procedure sio_$i_init(var desc: sio_$desc_t); extern;

{ SIO_$K_TIMED_BREAK - hold a break on a serial line for a time. }
procedure sio_$k_timed_break(in line: integer; in duration: pinteger;
                             out status: status_$t);
  extern;

{ SIO_$K_SIGNAL_WAIT - wait for one of a serial line's modem signals. }
procedure sio_$k_signal_wait(in line: integer; in signals: sio_$flags_t;
                             out status: status_$t);
  extern;

{ SIO_$K_SET_PARAM - set a serial line's parameters. }
procedure sio_$k_set_param(in line: integer; in params: sio_$params_t;
                           in mask: sio_$flags_t; out status: status_$t);
  extern;

{ SIO_$K_INQ_PARAM - a serial line's parameters. }
procedure sio_$k_inq_param(in line: integer; out params: sio_$params_t;
                           in mask: sio_$flags_t; out status: status_$t);
  extern;
