{ term/term.ins.pas - the terminal manager (TERM_, OS_TERM and
  OS_TERM_INIT), for the Domain Pascal tree.

  The headings, in map order, and what the Pascal files use; the two
  modules' files are term/os_term.pas and term/os_term_init.pas.  Types
  that would name the ec, tty or kbd inserts' are declared by size here,
  since not every user includes those.

  Include base/base.ins.pas and suma/suma.ins.pas before it.
}

const
  { 16#000B0004, "invalid option passed to term_$control" (OS / terminal
    manager, stcode.db.10.2).  TERM_$CONTROL, TERM_$INQUIRE and
    TERM_$GET_EC store it. }
  status_$term_invalid_option = 16#000B0004;

type
  { The characters TERM_$WRITE writes, by address (for VFMT_$WRITE,
    vfmt/write.pas).  The routine passes the slot on to TTY_$K_PUT's `in
    buffer: univ tty_$chars_t', whose type, `array[1..1] of char'
    (tty/tty.ins.pas), this repeats so that this file needs no
    tty.ins.pas: the old idiom for a buffer of any length, passed
    `univ'. }
  term_$chars_t = array[1..1] of char;

  { A display terminal table entry, 0x38 bytes.  The pointers whose
    targets have no Pascal type yet are univ_ptr; the reserved areas and
    the byte fields are chars.  TTY_$I_GET_DESC (tty/i_get_desc.pas)
    reads handler_ptr and discipline (a word); the element size is
    formed as 0x38 (64x - 8x).  SIO_$I_GET_DESC reads tty_handler.  The
    first 0x24 bytes are three eventcounts of 12 bytes: sio_$init_dtte
    passes +0x0C, +0x18 and +0x00 to EC_$INIT's `out' eventcount, and
    TERM_$GET_EC passes +0x0C and +0x18 to EC2_$REGISTER_EC1.  They are
    declared as their 12 bytes (ec/ec.ins.pas ec_$eventcount_t), so that
    this file needs no ec.ins.pas (vfmt/vfmt.pas includes none); their
    addresses convert to ec_$eventcount_ptr_t (`addr' is a univ_ptr).
    flags is a boolean: TERM_$READ tests its sign, TERM_$CONTROL stores
    the caller's boolean, and sio_$init_dtte clears it. }
  dtte_t = record
    ec_00: array[1..12] of char;          { 0x00: an ec_$eventcount_t }
    input_ec: array[1..12] of char;       { 0x0C: an ec_$eventcount_t }
    output_ec: array[1..12] of char;      { 0x18: an ec_$eventcount_t }
    handler_ptr: univ_ptr;                { 0x24: the line's descriptor,
                                            TTY_$I_GET_DESC's result }
    tty_handler: univ_ptr;                { 0x28 }
    alt_handler: univ_ptr;                { 0x2C }
    ptr_30: univ_ptr;                     { 0x30 }
    discipline: integer;                  { 0x34 }
    flags: boolean;                       { 0x36 }
    pad_37: char;                         { 0x37 }
  end;
  dtte_ptr_t = ^dtte_t;

  { The members of term_$value_t's word set (below). }
  term_$bits_t = set of 0..15;

  { The value of TERM_$CONTROL and TERM_$INQUIRE, by address: each option
    reads or writes it as another type at its first byte.  TERM_$CONTROL
    passes its slot on unchanged as TTY_$K_SET_FUNC_CHAR's `in ch: char',
    TTY_$K_ENABLE_FUNC's `in enable: boolean', TTY_$K_SET_INPUT_FLAG's
    boolean, SIO_$K_TIMED_BREAK's pinteger; it reads a byte by its sign,
    a byte by value, a word, the word's bits; and takes the address of 8
    bytes for TTY_$K_SET_PGROUP's uid_$t.  TERM_$INQUIRE writes bytes,
    words and 8 bytes.  One object of these types at one address is a
    variant record (ref 3.10.4); its size is the largest variant's, 8. }
  term_$value_t = record
    case integer of
      1: (b: boolean);
      2: (c: char);
      3: (w: pinteger);
      4: (bits: term_$bits_t);
      5: (uid: uid_$t);
  end;

var
  { DTTE, a map symbol in OS_TERM_INIT's data (+0x12A0).  Compiled code
    of other modules indexes it from the symbol's own address with no
    displacement for element 0 (TTY_$I_GET_DESC): another unit's
    variable, lower bound 0.  Four entries (TERM_$GET_REAL_LINE refuses
    lines above 3); the map's next symbol, TTY_$SPIN_LOCK, leaves 0xE4
    bytes, 4 x 0x38 and 4 more.  Defined by term/os_term_init.pas, which
    reaches it off A5 (TERM_$INQ_DISCIPLINE). }
  dtte: extern array[0..3] of dtte_t;

  { TTY_$SPIN_LOCK, a map symbol in OS_TERM_INIT's data (+0x1384): the
    spin lock of the TTY descriptors, defined by term/os_term_init.pas.
    TERM_$SET_REAL_LINE_DISCIPLINE passes it off A5 to ML_$SPIN_LOCK and
    _UNLOCK; the TTY routines by its address (tty/i_buf_put.pas;
    tty/tty.pas declares it extern itself and does not include this
    file).  integer32, as tty/tty.pas has it. }
  tty_$spin_lock: extern integer32;

  { TERM_$MAX_DTTE, a map symbol in OS_TERM_INIT's data (+0x1388, after
    TTY_$SPIN_LOCK): the number of display terminal table entries in use
    (zero in the image, set at boot).  Compiled code reads it as a word
    at its absolute address, compared unsigned with a line number
    (KBD_$GET_DESC, TERM_$GET_REAL_LINE).  So another unit's variable,
    and pinteger, the type of the line numbers it is compared with
    (kbd/kbd.ins.pas; TERM_$GET_REAL_LINE's result below).  TERM_$INIT
    stores 3, as its module's variable. }
  term_$max_dtte: extern pinteger;

  { TERM_$PCHIST_FLAG, the map's one symbol in OS_TERM's .DATA segment (4
    bytes): defined by term/os_term.pas.  No code addresses it (a byte
    search of the image finds nothing), so its type is not known;
    integer32, its size, zero in the image. }
  term_$pchist_flag: extern integer32;

{ Routine headings, in map order. }

{ TERM_$GET_REAL_LINE - map a terminal line to the real line it stands
  for. }
function term_$get_real_line(line: integer; out status: status_$t):
  pinteger; options(extern, val_param);

{ TERM_$SEND_KBD_STRING - put a string into the console keyboard's input. }
procedure term_$send_kbd_string(in str: univ term_$chars_t; in len: integer);
  extern;

{ TERM_$SET_DISCIPLINE - set a terminal line's discipline. }
procedure term_$set_discipline(in line: integer; in discipline: integer;
                               out status: status_$t);
  extern;

{ TERM_$SET_REAL_LINE_DISCIPLINE - set a real line's discipline. }
procedure term_$set_real_line_discipline(in line: pinteger;
                                         in discipline: integer;
                                         out status: status_$t);
  extern;

{ TERM_$INQ_DISCIPLINE - report a terminal line's discipline. }
procedure term_$inq_discipline(in line: integer; out discipline: integer;
                               out status: status_$t);
  extern;

{ TERM_$INIT - set up the terminal lines. }
procedure term_$init(in mode: integer; in line: integer); extern;

{ TERM_$READ - read characters from a terminal line. }
function term_$read(in line: integer; out buffer: univ term_$chars_t;
                    in count: pinteger; out status: status_$t): pinteger;
  extern;

{ TERM_$READ_COND - read the characters a terminal line has, without
  waiting. }
function term_$read_cond(in line: integer; out buffer: univ term_$chars_t;
                         in count: pinteger; out status: status_$t):
  pinteger;
  extern;

{ TERM_$WRITE - write characters to a terminal line. }
procedure term_$write(in line: integer; in buffer: univ term_$chars_t;
                      count: pinteger; out status: status_$t);
  extern;

{ TERM_$CONTROL - set an attribute of a terminal line. }
procedure term_$control(in line: integer; in option: integer;
                        in value: univ term_$value_t;
                        out status: status_$t);
  extern;

{ TERM_$INQUIRE - report an attribute of a terminal line. }
procedure term_$inquire(in line: integer; in option: integer;
                        out value: univ term_$value_t;
                        out status: status_$t);
  extern;

{ TERM_$GET_EC - the EC2 handle of a terminal line's input or output
  eventcount. }
procedure term_$get_ec(in ec_id: pinteger; in line: integer;
                       out ec_ret: univ_ptr; out status: status_$t);
  extern;

{ TERM_$HELP_CALLBACK - the terminal help callback. }
procedure term_$help_callback; extern;

{ TERM_$PCHIST_ENABLE - turn the PC history sampling on the serial line on
  or off. }
procedure term_$pchist_enable(in count: integer; out status: status_$t);
  extern;

{ TERM_$ENQUEUE_TPAD - hand the queued tablet samples to TPAD_$DATA. }
procedure term_$enqueue_tpad(in buffer_ptr_ptr: tpad_buffer_ptr_ptr_t);
  extern;

{ TERM_$P2_CLEANUP - drop a dying process's ownership of the terminal
  lines. }
procedure term_$p2_cleanup(in as_id: integer); extern;

{ ---- TERM's dispatch codes, named. ----

  TERM_$CONTROL's and TERM_$INQUIRE's option numbers (their `case option
  of', jump tables).  No Apollo insert declares TERM's options; the
  user-level SIO_$CONTROL's option type, Apollo's sys/ins/sio.ins.pas
  sio_$opt_t, has the same ordinal and the same meaning for most of
  them, and those take its names (term_$opt_ plus the sio_$ name).
  Where TERM's number differs from sio_$opt_t's ordinal for the same
  function, or there is no sio_$ counterpart, the name says what the arm
  does, and its comment gives sio_$opt_t's ordinal where there is one. }
const
  term_$opt_erase = 0;                    { sio_$erase }
  term_$opt_kill = 1;                     { sio_$kill }
  term_$opt_eofchr = 2;                   { sio_$eofchr }
  term_$opt_raw = 3;                      { sio_$raw }
  term_$opt_no_echo = 4;                  { sio_$no_echo }
  term_$opt_no_nl = 5;                    { sio_$no_NL }
  term_$opt_speed = 6;                    { sio_$speed }
  term_$opt_line_flag = 7;                { the DTTE's flags byte }
  term_$opt_host_sync = 8;                { sio_$host_sync's
                                            meaning (stop/start enabled),
                                            its ordinal there 7 }
  term_$opt_ignored_9 = 9;                { control ignores it,
                                            inquire answers 0 }
  term_$opt_quit_enable = 10;             { sio_$quit_
                                            enable's meaning, its ordinal
                                            there 9 }
  term_$opt_input_sync = 11;              { sio_$input_sync's
                                            meaning (ixoff), its ordinal
                                            there 10 }
  term_$opt_rts = 12;                     { sio_$rts }
  term_$opt_dtr = 13;                     { sio_$dtr }
  term_$opt_dcd = 14;                     { sio_$dcd (inquire only) }
  term_$opt_dcd_enable = 15;              { sio_$dcd_enable }
  term_$opt_cts = 16;                     { sio_$cts (inquire only) }
  term_$opt_cts_enable = 17;              { sio_$cts_enable }
  term_$opt_parity = 18;                  { sio_$parity }
  term_$opt_bits_per_char = 19;           { sio_$bits_per_char }
  term_$opt_stop_bits = 20;               { sio_$stop_bits }
  term_$opt_err_enable = 21;              { sio_$err_enable }
  term_$opt_send_break = 22;              { sio_$send_break }
  term_$opt_quitchr = 23;                 { sio_$quitchr }
  term_$opt_bp_enable = 24;               { sio_$bp_enable }
  term_$opt_int_enable = 25;              { sio_$int_enable }
  term_$opt_intchr = 26;                  { sio_$intchr }
  term_$opt_susp_enable = 27;             { sio_$susp_enable }
  term_$opt_suspchr = 28;                 { sio_$suspchr }
  term_$opt_raw_nl = 29;                  { sio_$raw_nl }
  term_$opt_pgroup = 30;                  { sio_$pgroup's
                                            meaning, its ordinal there 34 }
  term_$opt_hup_close = 31;               { sio_$hup_close }
  term_$opt_speed_force = 32;             { sio_$speed_
                                            force's meaning (the baud
                                            rate with mask member 1), its
                                            ordinal there 33 }
  term_$opt_flush_in = 33;                { sio_$flush_in's
                                            meaning, its ordinal there 37 }
  term_$opt_flush_out = 34;               { sio_$flush_out's,
                                            there 38 }
  term_$opt_drain_out = 35;               { sio_$drain_out's,
                                            there 39 }
  term_$opt_kbd_mode = 36;                { KBD_$SET_KBD_MODE }

  { TERM_$GET_EC's eventcount key ("0 = input, 1 = output"). }
  term_$ec_input = 0;
  term_$ec_output = 1;

  { The DTTE's discipline word (+0x34; TERM_$SET_REAL_LINE_DISCIPLINE's
    `case', TTY_$I_GET_DESC's compare with 2): "0=TTY, 1=disable alt,
    2=enable alt, 3=SUMA". }
  term_$disc_tty = 0;
  term_$disc_disable_alt = 1;
  term_$disc_enable_alt = 2;
  term_$disc_suma = 3;
{ ---- end of TERM's dispatch codes ---- }
