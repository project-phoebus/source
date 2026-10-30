{ kbd/kbd.ins.pas - the keyboard driver (KBD): constants, types, the
  global variable TERM_$TPAD_BUFFER and the routine headings, for the
  Domain Pascal tree.

  The KBD module (kbd/kbd.pas) includes it, and so will the modules that
  call KBD routines (OS_TERM, OS_TERM_INIT, SMD, CRASH_SYSTEM's callers)
  or reach TERM_$TPAD_BUFFER (BITPAD's SUMA_$RCV and SUMA_$INIT).
  Include base/base.ins.pas, ec/ec.ins.pas, smd/smd.ins.pas and
  suma/suma.ins.pas before it.

  Apollo's customer kbd.ins.pas of SR10.2 (sr10.2-install/install/
  ri.apollo.os.v.10.2/sys/ins/kbd.ins.pas, "KBD.INS.PAS, /sys/ins, JBT,
  04/15/83") is the user's table of key codes, "Definitions for
  non-ascii keyboard keys, for use in borrow mode and direct mode in
  gpr_$event_wait": constants only, no types or routines.

  The codes
  kbd_$translate_key maps (kbd/rcv.pas) are eight of them, with Apollo's
  names below; the image's mapping fits their names (the CR key to CR,
  the three tab keys to HT, BS to BS).

  The codes of the state table
  (kbd/kbd.pas) are the raw bytes the keyboard sends, before the
  translation table, so Apollo's names are not used there.  The
  descriptor, the state machine's tables and the routines have no Apollo
  declaration: their layouts are the image's.
}

const
  { Apollo's key codes (kbd.ins.pas, as declared there: `KBD_$BS  =
    chr(16#95);' ...), the ones kbd_$translate_key tests, in its order of
    test. }
  kbd_$f1   = chr(16#C0);
  kbd_$r2   = chr(16#91);
  kbd_$r3   = chr(16#92);
  kbd_$bs   = chr(16#95);
  kbd_$cr   = chr(16#96);
  kbd_$tab  = chr(16#97);
  kbd_$stab = chr(16#98);
  kbd_$ctab = chr(16#99);

  { The member of the descriptor's flags (kbd_$flags_t, below) that
    records KBD_$GET_CHAR_AND_MODE's command as sent. }
  kbd_$flag_cmd_sent = 0;

  { The key ring's capacity.  kbd_$fetch_key and kbd_$process_key wrap a
    position at 16#40, and KBD_$INIT stores 16#40 into both rings' size
    words. }
  kbd_$ring_size = 64;

  { The key ring's own capacity: 64 as the transmit buffer's, or 512
    with `kbd_key_ring_512' (KBD_$INIT's size word for the ring at
    +0x58; the transmit buffer then at +0x25E). }
%if kbd_key_ring_512 %then
  kbd_$key_ring_size = 512;
%else
  kbd_$key_ring_size = 64;
%endif

type
  { An entry of the state machine's table, 2 bytes: the key at +0, then
    a byte whose high nibble is the action and low nibble the next
    state.  A packed record (ref 3.10.7, Table 3-3): the char takes byte
    0, and two 4-bit subranges the next byte, the first field in its high
    bits ("left to right within bytes").  The image reads them as packed
    fields: the action shifted down from the byte (KBD_$RCV,
    kbd_$fetch_key; the RIP form likewise, the mask formed with a move
    because 16#F0 is no quick constant), the next state masked with no
    shift (the field at the bottom of its byte), the key compared as a
    byte (kbd_$state_lookup).  The one store, of the field's largest
    value 15, sets every bit of the field with an or alone, here through
    a register and on the record's word (TODO(pascal) in kbd/rcv.pas). }
  kbd_$state_entry_t = packed record
    key: char;                            { +0 }
    action: 0..15;                        { +1, bits 7..4 }
    next_state: 0..15;                    { +1, bits 3..0; 15: the
                                            keyboard type's escape state }
  end;
  kbd_$state_entry_ptr_t = ^kbd_$state_entry_t;

  { A state's range of entries: kbd_$state_lookup scans entries first ..
    limit - 1 and falls back to entry limit.  It reads both words with
    one scaled index: 4-byte elements, first at +0, limit at +2. }
  kbd_$state_range_t = record
    first: integer;                       { +0 }
    limit: integer;                       { +2 }
  end;

  { The bytes of a tablet sample that KBD_$RCV's touchpad arms store
    through the descriptor's tpad_ptr, at displacements 0, 1 and 2: an
    array of three chars from 0. }
  kbd_$tpad_bytes_t = array[0..2] of char;
  kbd_$tpad_bytes_ptr_t = ^kbd_$tpad_bytes_t;

  { A keyboard type string, 4 characters from 0: the descriptor's
    kbd_type_str (0x40..0x43, up to kbd_type_len at 0x44), and, as an
    `in' or `out' `univ' array (ref 5.3.3), the caller's string that
    kbd_$set_type, KBD_$SET_KBD_TYPE and KBD_$INQ_KBD_TYPE take.  The
    copies index both sides with one register from 0 at displacement 0
    (kbd_$set_type, KBD_$INQ_KBD_TYPE), and kbd_$set_type clears the
    field's second character and reads the caller's at +1: element 0 at
    the array's address, so the lower bound is 0 (a 1-based array would
    put element 1 there and fold -1 into the displacement, as
    DTTY_$WRITE_STRING does).  A constant subscript must lie in the
    bounds (dpc: "index out of range" for [1] of a one-element formal),
    so the caller's string has at least two elements; the field's four
    are taken.  The constant '2' that KBD_$INIT passes is its own 2-byte
    cell, not extended to the formal's size. }
  kbd_$type_str_t = array[0..3] of char;

  { The characters KBD_$PUT is given, as an `in' `univ' array, the idiom
    of tty_$chars_t (tty/tty.ins.pas): a one-element formal for a buffer
    of any length.  KBD_$PUT and kbd_$put_line only pass its address on,
    so its bounds are not seen; 1 to 1 as tty_$chars_t. }
  kbd_$chars_t = array[1..1] of char;

  { A circular buffer of 64 characters, 70 bytes: the descriptor's key
    ring at 0x58 and its transmit buffer at 0x9E.  The shape of
    tty_$cbuf_t (tty/tty.ins.pas) with 64 elements: KBD_$INIT gives both
    the same three words (head := 1 and tail := 1 merged); data[i] is at
    0x5D + i (kbd_$fetch_key, kbd_$process_key), a 1-based array at
    0x5E.  The second is the console's transmit buffer: SIO_$INIT passes
    the address of this descriptor's +0x9E inside TERM_$DATA (the
    descriptors are 0xE4 apart, by port; sio/init.pas) to SIO_$INIT_DESC
    as the SIO descriptor's txbuf (sio/init_desc.pas), where a serial
    line gets its TTY descriptor's output buffer, a tty_$cbuf_t.  The
    positions are compared unsigned-with-unsigned at word width
    (kbd_$process_key) against the parent's pinteger new_head
    (zero-extended where it meets a signed word): so pinteger.  size is
    only stored here: integer. }
  kbd_$ring_t = record
    head: pinteger;                       { +0x00: consumer position }
    tail: pinteger;                       { +0x02: producer position }
    size: integer;                        { +0x04: always kbd_$ring_size }
    data: array[1..kbd_$ring_size] of char;   { +0x06 }
  end;

  { The key ring: kbd_$ring_t's shape with kbd_$key_ring_size
    characters (70 or 518 bytes). }
  kbd_$key_ring_t = record
    head: pinteger;                       { +0x00: consumer position }
    tail: pinteger;                       { +0x02: producer position }
    size: integer;                        { +0x04: always
                                            kbd_$key_ring_size }
    data: array[1..kbd_$key_ring_size] of char;   { +0x06 }
  end;

  { The routine a line's keyboard data go to when one is installed.
    KBD_$RCV calls it with the descriptor's user_data by value as a
    longword and a character by value in a word slot, after the pad, and
    reads no result: a val_param procedure type (ref 5.2, Table 5-1). }
  kbd_$handler_t =
    ^procedure(user_data: integer32; ch: char); options(val_param);

  { Three handler longwords, the 12 bytes the OS_TERM_INIT module-local
    os_term_init copies whole into a descriptor's +0x04 (below). }
  kbd_$handler_block_t = array[1..3] of univ_ptr;

  { The first of them, the line's transmit start (term/os_term_init.pas
    term_$kbd_handlers: SIO_$I_TSTART): with `kbd_commands',
    kbd_$txbuf_put calls it with the descriptor's field_10 by value as
    a longword and reads no result, a val_param procedure type (ref
    5.2, Table 5-1). }
  kbd_$tstart_t = ^procedure(desc: univ_ptr); options(val_param);

  { The descriptor's flags word, a set (ref 3.9.3: member k is bit k of
    the word).  KBD_$INIT clears it; with `kbd_commands' member
    kbd_$flag_cmd_sent records that KBD_$GET_CHAR_AND_MODE has sent its
    command, and KBD_$CRASH_INIT and KBD_$RCV's action 7 clear it. }
  kbd_$flags_t = set of 0..15;

  kbd_$desc_ptr_t = ^kbd_$desc_t;

  { The keyboard descriptor of a line, 0xE4 bytes (0x2A4 with
    `kbd_key_ring_512', the transmit buffer at 0x25E): SIO_$INIT lays the
    console's descriptors out 0xE4 apart (sio/init.pas), and the buffer
    at 0x9E is 0x46 bytes.  Where the image shows one object over
    several words:
    - sample, 0x1C..0x2B, a suma_sample_t: KBD_$RCV copies the 16 bytes
      into TERM_$TPAD_BUFFER as one record (suma/suma.ins.pas): the delta
      time (0x1C), one time_$clock_t (0x20..0x25, sample.timestamp), the
      byte at 0x26 (sample.id_flags), 0x27..0x2B (sample.reserved_0b ..
      y_low);
    - ring, kbd_$key_ring_t, and txbuf, kbd_$ring_t (above).
    Each other field, as the KBD routines use it:
    - handler 0x00: tested (KBD_$RCV), called (above);
    - handlers 0x04..0x0F and field_10 0x10: the OS_TERM_INIT
      module-local os_term_init (os/term_init.pas) fills them before it
      calls KBD_$INIT: field_10 with the SIO descriptor's address, and
      0x04..0x0F as one 12-byte block from its handler block's +4, a
      record assignment of a 12-byte type; with `kbd_commands'
      kbd_$txbuf_put calls handlers[1] (kbd_$tstart_t) with field_10;
    - user_data 0x14: pushed by value, integer32;
    - last_time 0x18: subtracted from and stored with the low 32 bits of
      a clock: integer32;
    - tpad_ptr 0x2C, tpad_buffer 0x30: above and suma/suma.ins.pas;
      KBD_$INIT stores addr(term_$tpad_buffer) in tpad_buffer;
    - ktt_ptr 0x34: indexed by a key (smd/smd.ins.pas, smd_$ktt_t);
    - state 0x38, sub_state 0x3A, kbd_type_idx 0x3C, pending_mode 0x3E:
      words, used as table indices and stored: integer;
    - kbd_type_str 0x40: kbd_$type_str_t (above; kbd_$set_type copies at
      most 2 characters);
    - kbd_type_len 0x44: compared signed (kbd_$set_type, the value just
      stored there; KBD_$INQ_KBD_TYPE): integer;
    - flags 0x46: cleared (KBD_$INIT), and with `kbd_commands' member 0
      set, tested and cleared as a bit of the word's low byte:
      kbd_$flags_t;
    - key_ec 0x48: an eventcount's address, pushed for
      EC_$ADVANCE_WITHOUT_DISPATCH's `var' eventcount:
      ec_$eventcount_ptr_t (the OS_TERM_INIT module-local os_term_init
      stores its DTTE entry's address there);
    - ec 0x4C: passed by address to EC_$INIT and
      EC_$ADVANCE_WITHOUT_DISPATCH, and with `kbd_commands' its value
      read and its address passed to EC_$WAIT (kbd_$put_line):
      ec_$eventcount_t. }
  kbd_$desc_t = record
    handler: kbd_$handler_t;              { 0x00 }
    handlers: kbd_$handler_block_t;       { 0x04 }
    field_10: univ_ptr;                   { 0x10 }
    user_data: integer32;                 { 0x14 }
    last_time: integer32;                 { 0x18 }
    sample: suma_sample_t;                { 0x1C..0x2B }
    tpad_ptr: kbd_$tpad_bytes_ptr_t;      { 0x2C }
    tpad_buffer: tpad_buffer_ptr_t;       { 0x30 }
    ktt_ptr: smd_$ktt_ptr_t;              { 0x34 }
    state: integer;                       { 0x38 }
    sub_state: integer;                   { 0x3A }
    kbd_type_idx: integer;                { 0x3C }
    pending_mode: integer;                { 0x3E }
    kbd_type_str: kbd_$type_str_t;        { 0x40 }
    kbd_type_len: integer;                { 0x44 }
    flags: kbd_$flags_t;                  { 0x46 }
    key_ec: ec_$eventcount_ptr_t;         { 0x48 }
    ec: ec_$eventcount_t;                 { 0x4C }
    ring: kbd_$key_ring_t;                { 0x58..0x9D: the key ring }
    txbuf: kbd_$ring_t;                   { 0x9E..0xE3 (0x25E..0x2A3):
                                            the console's transmit
                                            buffer }
  end;

var
  { TERM_$TPAD_BUFFER, the map's one symbol inside KBD's data segment
    (+0x58): a global variable of the KBD module, whatever its TERM_
    name.  The KBD routines reach it off the module's block (KBD_$RCV
    through A5, KBD_$INIT by the block's absolute address), and BITPAD's
    routines by its own address.  Declared extern here and defined in
    kbd/kbd.pas (ref 7.2.2, Method 2), as LOG_$LOGFILE_PTR is
    (log/log.ins.pas). }
  term_$tpad_buffer: extern tpad_buffer_t;

{ Routine headings.  The KBD_$ routines that are global symbols in the
  SAU2 map, in map order.  The bodies repeat the full heading (ref 7.3.4,
  Method 2).  KBD_$GET_DESC and KBD_$RESET are not in KBD's segments
  (kbd/README.md); their bodies are fragments for the OS_TERM and
  OS_TERM_INIT modules. }

{ KBD_$GET_DESC - the keyboard descriptor of a terminal line. }
function kbd_$get_desc(in line: pinteger; out status: status_$t):
  kbd_$desc_ptr_t; extern;

{ KBD_$RESET (kbd/reset.pas), the first routine of OS_TERM_INIT's
  WIRED_PROC segment: an empty procedure.  Its one caller is the
  hand-written CRASH_SYSTEM, with nothing pushed.  No parameters. }
procedure kbd_$reset; extern;

{ KBD_$RCV - the console line's receive handler: one byte from the
  keyboard. }
procedure kbd_$rcv(var kbd: kbd_$desc_t; ch: char);
  options(extern, val_param);

{ KBD_$CRASH_INIT - prepare the keyboard for the crash console. }
procedure kbd_$crash_init; extern;

{ KBD_$OUTPUT_BUFFER_DRAINED - the console's transmit buffer has drained. }
procedure kbd_$output_buffer_drained(var kbd: kbd_$desc_t); extern;

{ KBD_$PUT - write to a keyboard line. }
procedure kbd_$put(in line: pinteger; in type_arg: integer;
                   in str: univ kbd_$chars_t; in length: integer;
                   out status: status_$t); extern;

{ KBD_$INIT - initialize a keyboard descriptor. }
procedure kbd_$init(var kbd: kbd_$desc_t); extern;

{ KBD_$GET_CHAR_AND_MODE - fetch one key and its mode code. }
function kbd_$get_char_and_mode(in line: pinteger; out char_out: char;
                                out mode_out: char; out status: status_$t):
  boolean; extern;

{ KBD_$SET_KBD_MODE - set a line's keyboard mode. }
procedure kbd_$set_kbd_mode(in line: pinteger; in mode: char;
                            out status: status_$t); extern;

{ KBD_$SET_KBD_TYPE - set a line's keyboard type string. }
procedure kbd_$set_kbd_type(in line: pinteger;
                            in type_str: univ kbd_$type_str_t;
                            in type_len: pinteger; out status: status_$t);
  extern;

{ KBD_$INQ_KBD_TYPE - return a line's keyboard type string. }
procedure kbd_$inq_kbd_type(in line: pinteger;
                            out type_buf: univ kbd_$type_str_t;
                            out type_len: pinteger; out status: status_$t);
  extern;
