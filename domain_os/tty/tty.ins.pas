{ tty/tty.ins.pas - the TTY line discipline: constants, types and routine
  headings, for the Domain Pascal tree.

  The TTY module (tty.pas) includes it, and so will other subsystems'
  modules that call TTY routines.  Include base/base.ins.pas and
  ec/ec.ins.pas before it.

  The record offsets are the image's.  Where Apollo's customer
  tty.ins.pas of SR10.2 declares a type the descriptor holds (the flag
  sets, the function slots, the delays, the input break mode), its
  declaration is used, as it stands there ("Apollo's types" below), with
  its names.
}

const
  { Status codes, subsystem 0x35. }
  status_$tty_invalid_option               = 16#00350001;
  status_$tty_invalid_function             = 16#00350002;
  status_$tty_buffer_full                  = 16#00350004;
  status_$tty_eof                          = 16#00350005;
  status_$tty_invalid_output_buffer_length = 16#00350006;
  status_$tty_quit_while_waiting_for_input = 16#00350007;
  status_$tty_get_conditional_failed       = 16#00350008;
  status_$tty_input_buffer_overrun         = 16#00350009;
  status_$tty_would_block                  = 16#0035000A;

  tty_$buf_size = 256;                 { a circular buffer's size }
  tty_$max_func_chars = 16#12;            { function slots 0..17,
                                            tty_$func_erase ..
                                            tty_$func_reserved_18 }

  { Character classes, the values of char_class[]. }
  tty_$class_sigint   = 16#00;
  tty_$class_sigquit  = 16#01;
  tty_$class_sigtstp  = 16#02;
  tty_$class_break    = 16#03;
  tty_$class_eof      = 16#04;
  tty_$class_xoff     = 16#05;
  tty_$class_xon      = 16#06;
  tty_$class_del      = 16#07;
  tty_$class_kill     = 16#08;
  tty_$class_werase   = 16#09;
  tty_$class_reprint  = 16#0A;
  tty_$class_nl       = 16#0B;
  tty_$class_discard  = 16#0C;
  tty_$class_flushout = 16#0D;
  tty_$class_cr       = 16#0E;
  tty_$class_crlf     = 16#0F;
  tty_$class_tab      = 16#10;
  tty_$class_crash    = 16#11;
  tty_$class_normal   = 16#12;

  { Signal numbers passed to TTY_$I_SIGNAL. }
  tty_$sig_hup   = 16#01;
  tty_$sig_int   = 16#02;
  tty_$sig_quit  = 16#03;
  tty_$sig_tstp  = 16#15;
  tty_$sig_cont  = 16#16;
  tty_$sig_winch = 16#1A;

  { Members of state_flags, as bit numbers (all in the low byte, at
    0x09). }
  tty_$st_output_wait    = 0;
  tty_$st_input_wait     = 1;
  tty_$st_output_stopped = 2;
  tty_$st_sig_pend       = 4;
  tty_$st_output_flush   = 5;
  tty_$st_eof_pend       = 6;

  { Members of pending_signal, as bit numbers. }
  tty_$err_callback = 0;
  tty_$err_overflow = 1;

type
  { Apollo's types.  The declarations below are the customer tty.ins.pas
    of SR10.2 (sr10.2-install/install/ri.apollo.os.v.10.2/sys/ins/
    tty.ins.pas, "TTY.INS.PAS, /us/sys/ins, everett_m, 01/15/89"),
    copied as they stand there, enumerators and comments included: the
    user interface's types, which the kernel's TTY_$K_ entry points take
    and the descriptor holds.  Only the types this tree uses are copied.

    Each enumeration has 32 values, so a set of one takes 32 bits, member
    k at bit k (ref 3.9.3); an enumerated variable takes one 16-bit word
    (ref 3.7.1).  The ordinal of each name is its position from 0;
    Apollo's reserved names number the positions from 1
    (tty_$if_reserved_14 is ordinal 13, tty_$func_reserved_18 ordinal
    17).

    The image agrees with every name the TTY code tests but one, against
    Apollo's comment and not the ordinal: under tty_$of_cr_to_crnl
    (output member 0) a CR is sent as LF, CR to NL, not "CR to CR-NL",
    and tty_$i_newline sends CR alone under it.  The name is kept; the
    image wins on what the flag does. }
  tty_$input_flag_t = (
      tty_$if_echo,       { Echo input characters }
      tty_$if_ixoff,      { Generate flow control for incoming data (tandem) }
      tty_$if_ixany,      { Any char restarts output for func_stop }
      tty_$if_cr_to_nl,   { Convert input CR to NL }
      tty_$if_nl_to_cr,   { Convert input NL to CR }
      tty_$if_strip,      { Strip to 7 bits }
      tty_$if_polite,     { Block output if partial input line }
      tty_$if_hup_close,  { Hang up on last tty close }
      tty_$if_excl_use,   { One open on this line at a time }
      tty_$if_ignore_cr,  { Ignore CR (throw it away when read) }
      tty_$if_queue_brk,  { Put BREAK conditions on the queue rather than error reporting }
      tty_$if_queue_par,  { Put parity and framing errors (except BREAK) on the queue rather than error reporting }
      tty_$if_flag_errs,  { Preceed queued errors by '\377' '\0'. If not tty_$if_strip, report '\377' as '\377' '\377' }
      tty_$if_reserved_14,
      tty_$if_reserved_15,
      tty_$if_reserved_16,
      tty_$if_reserved_17,
      tty_$if_reserved_18,
      tty_$if_reserved_19,
      tty_$if_reserved_20,
      tty_$if_reserved_21,
      tty_$if_reserved_22,
      tty_$if_reserved_23,
      tty_$if_reserved_24,
      tty_$if_reserved_25,
      tty_$if_reserved_26,
      tty_$if_reserved_27,
      tty_$if_reserved_28,
      tty_$if_reserved_29,
      tty_$if_reserved_30,
      tty_$if_reserved_31,
      tty_$if_reserved_32
  );

  tty_$input_flag_set_t = set of tty_$input_flag_t;

  tty_$output_flag_t = (
      tty_$of_cr_to_crnl,     { Convert output CR to CR-NL }
      tty_$of_nl_to_crnl,     { Convert output NL to CR-NL }
      tty_$of_cr_to_nl,       { Convert output CR to NL (wha?) }
      tty_$of_no_cr,          { Inhibit CR at column 0 }
      tty_$of_xtabs,          { Expand tabs }
      tty_$of_reserved_6,
      tty_$of_reserved_7,
      tty_$of_reserved_8,
      tty_$of_reserved_9,
      tty_$of_reserved_10,
      tty_$of_reserved_11,
      tty_$of_reserved_12,
      tty_$of_reserved_13,
      tty_$of_reserved_14,
      tty_$of_reserved_15,
      tty_$of_reserved_16,
      tty_$of_reserved_17,
      tty_$of_reserved_18,
      tty_$of_reserved_19,
      tty_$of_reserved_20,
      tty_$of_reserved_21,
      tty_$of_reserved_22,
      tty_$of_reserved_23,
      tty_$of_reserved_24,
      tty_$of_reserved_25,
      tty_$of_reserved_26,
      tty_$of_reserved_27,
      tty_$of_reserved_28,
      tty_$of_reserved_29,
      tty_$of_reserved_30,
      tty_$of_reserved_31,
      tty_$of_reserved_32
  );

  tty_$output_flag_set_t = set of tty_$output_flag_t;

  tty_$echo_flag_t = (
      tty_$echo_bs_erase,     { erase generates ascii BS }
      tty_$echo_crt_erase,    { crt style erase }
      tty_$echo_crt_kill,     { crt style kill }
      tty_$echo_ptr_erase,    { printer style erase }
      tty_$echo_cntl_with_hat, { Echo control characters as ^X }
      tty_$echo_kill_nl,      { go to a newline after the kill }
      tty_$echo_reserved_7,
      tty_$echo_reserved_8,
      tty_$echo_reserved_9,
      tty_$echo_reserved_10,
      tty_$echo_reserved_11,
      tty_$echo_reserved_12,
      tty_$echo_reserved_13,
      tty_$echo_reserved_14,
      tty_$echo_reserved_15,
      tty_$echo_reserved_16,
      tty_$echo_reserved_17,
      tty_$echo_reserved_18,
      tty_$echo_reserved_19,
      tty_$echo_reserved_20,
      tty_$echo_reserved_21,
      tty_$echo_reserved_22,
      tty_$echo_reserved_23,
      tty_$echo_reserved_24,
      tty_$echo_reserved_25,
      tty_$echo_reserved_26,
      tty_$echo_reserved_27,
      tty_$echo_reserved_28,
      tty_$echo_reserved_29,
      tty_$echo_reserved_30,
      tty_$echo_reserved_31,
      tty_$echo_reserved_32
  );

  tty_$echo_flag_set_t = set of tty_$echo_flag_t;

  tty_$break_type_t = (
      tty_$break_on_eol,
      tty_$break_on_count,
      tty_$break_on_timer,
      tty_$break_on_timer_or_count,
      tty_$break_reserved_5,
      tty_$break_reserved_6,
      tty_$break_reserved_7,
      tty_$break_reserved_8,
      tty_$break_reserved_9,
      tty_$break_reserved_10,
      tty_$break_reserved_11,
      tty_$break_reserved_12,
      tty_$break_reserved_13,
      tty_$break_reserved_14,
      tty_$break_reserved_15,
      tty_$break_reserved_16,
      tty_$break_reserved_17,
      tty_$break_reserved_18,
      tty_$break_reserved_19,
      tty_$break_reserved_20,
      tty_$break_reserved_21,
      tty_$break_reserved_22,
      tty_$break_reserved_23,
      tty_$break_reserved_24,
      tty_$break_reserved_25,
      tty_$break_reserved_26,
      tty_$break_reserved_27,
      tty_$break_reserved_28,
      tty_$break_reserved_29,
      tty_$break_reserved_30,
      tty_$break_reserved_31,
      tty_$break_reserved_32
  );

  { The layout (ref 3.10.2, 3.10.5.5): the tag field break_type, one word
    at 0; count a pinteger word at 2 and timer a linteger at 4, word
    aligned by `[aligned(1)]' (ref 3.10.6: "aligned(1) specifies word
    alignment").  8 bytes, the descriptor's 0x38..0x3F (tty_$desc_t
    below). }
  tty_$input_break_mode_t =
      record
          case break_type : tty_$break_type_t of
              tty_$break_on_timer,
              tty_$break_on_count,
              tty_$break_on_timer_or_count: (
                  count : pinteger;
                  timer: [aligned(1)] linteger
                  );
      end;

  tty_$delay_t = (
      tty_$delay_nl,
      tty_$delay_cr,
      tty_$delay_tab,
      tty_$delay_vt,
      tty_$delay_ff,
      tty_$delay_reserved_6,
      tty_$delay_reserved_7,
      tty_$delay_reserved_8,
      tty_$delay_reserved_9,
      tty_$delay_reserved_10,
      tty_$delay_reserved_11,
      tty_$delay_reserved_12,
      tty_$delay_reserved_13,
      tty_$delay_reserved_14,
      tty_$delay_reserved_15,
      tty_$delay_reserved_16,
      tty_$delay_reserved_17,
      tty_$delay_reserved_18,
      tty_$delay_reserved_19,
      tty_$delay_reserved_20,
      tty_$delay_reserved_21,
      tty_$delay_reserved_22,
      tty_$delay_reserved_23,
      tty_$delay_reserved_24,
      tty_$delay_reserved_25,
      tty_$delay_reserved_26,
      tty_$delay_reserved_27,
      tty_$delay_reserved_28,
      tty_$delay_reserved_29,
      tty_$delay_reserved_30,
      tty_$delay_reserved_31,
      tty_$delay_reserved_32
  );

  tty_$func_t = (
      tty_$func_erase,    { Erase previous character }
      tty_$func_erase_word,   { Erase previous "word" }
      tty_$func_kill,     { Erase current line }
      tty_$func_eof,      { End-of-file }
      tty_$func_eol,      { end of line }
      tty_$func_tab,      { tab }
      tty_$func_cr,       { carriage return }
      tty_$func_nl,       { newline }
      tty_$func_quit,     { Quit process }
      tty_$func_int,      { Interrupt process }
      tty_$func_susp,     { Suspend (Berkeley "stop") process }
      tty_$func_dsusp,    { Delayed suspend }
      tty_$func_quote,    { Quote next character }
      tty_$func_stop,     { Stop output ("xoff") }
      tty_$func_start,    { Resume output ("xon") }
      tty_$func_oflush,       { flush output }
      tty_$func_replay,       { Reshow current line }
      tty_$func_reserved_18,
      tty_$func_reserved_19,
      tty_$func_reserved_20,
      tty_$func_reserved_21,
      tty_$func_reserved_22,
      tty_$func_reserved_23,
      tty_$func_reserved_24,
      tty_$func_reserved_25,
      tty_$func_reserved_26,
      tty_$func_reserved_27,
      tty_$func_reserved_28,
      tty_$func_reserved_29,
      tty_$func_reserved_30,
      tty_$func_reserved_31,
      tty_$func_reserved_32
  );

  tty_$func_set_t = set of tty_$func_t;

  { Types.  The flag words are sets, member k being bit k of the field's
    value (ref 3.9.3): the member of ordinal k of Apollo's set types
    above, or the number k of tty_$flags16_t below.

    - state_flags (0x08) and pending_signal (0x0A): whole-word set
      operations, and member operations on the low byte: `set of 0..15'.
    - output_flags, raw_saved_output_flags, input_flags,
      raw_saved_input_flags, echo_flags and func_enabled (0x0C..0x20):
      one longword each, unions, differences and tests of a variable
      member: Apollo's 32-member sets.

    A test of a constant member comes in two forms in the SAU2 image, a
    bit test of the byte or word in memory and a test of the field
    loaded at its own size; the same field and member take both, so the
    form is not the type's (the TODO(pascal) below). }
  { TODO(pascal) when a member is tested in memory and when in a loaded copy

    Which form the compiler chooses when is open.  In the TTY code the
    loaded form occurs where the descriptor's address is read from a
    frame slot at each reference (a nested routine reaches that slot,
    or the static link), the memory form where the address is held in a
    register; but AST has a loaded test with the address held, and a
    loaded copy is also reused for later tests (TTY_$I_RCV, TTY_$I_ERR). }
  tty_$flags16_t = set of 0..15;

  { An unsigned word, for the parameters and results that the image
    compares unsigned or zero-extends.  A parameter's type must be a type
    name (ref 5.1, p. 5-2).  It is base's pinteger itself, not a second
    subrange of the same bounds: TERM_$WRITE, TERM_$READ and
    TERM_$READ_COND pass their pinteger counts by address to TTY_$K_PUT
    and TTY_$K_GET, which the type check allows only for the same type
    (ref 5.3.3, p. 5-10; ref 5.3.4.1). }
  tty_$uword_t = pinteger;

  { A position in a circular buffer.  TTY_$I_INIT sets every position to
    1 and every update keeps it in 1..256, so it is stored in 16 bits. }
  tty_$buf_pos_t = 1..tty_$buf_size;

  { A circular buffer, 262 bytes; data[i] is at 5 + i, the 1-based array
    at 6.  The three words are, for the input buffer, the read position,
    the tail and the size, and for the output buffer the head, the read
    position and the tail. }
  tty_$cbuf_t = record
    head: tty_$buf_pos_t;                 { 0x00: consumer position }
    tail: tty_$buf_pos_t;                 { 0x02: producer position }
    size: integer;                        { 0x04: always tty_$buf_size }
    data: array[1..tty_$buf_size] of char;  { 0x06 }
  end;

  tty_$desc_ptr_t = ^tty_$desc_t;

  { One of the six signal entries.  fault_status is a status, not a code
    address (TTY_$I_DXM_SIGNAL passes it to PROC2_$SIGNAL_PGROUP_OS). }
  tty_$signal_entry_t = record
    tty_desc: tty_$desc_ptr_t;            { 0x00 }
    fault_status: status_$t;              { 0x04 }
    signal_num: integer;                  { 0x08 }
    reserved: integer;                    { 0x0A: never written }
  end;

  { A pointer to a signal entry: TTY_$I_DXM_SIGNAL's argument, a pointer
    to DXM's copy of the entry. }
  tty_$signal_entry_ptr_t = ^tty_$signal_entry_t;

  { The handlers in the descriptor, each called with the line id by value
    as a longword and booleans by value in word slots: val_param routine
    types.  The status handler's result is an integer32 because the
    reference does not say that a function can return a record. }
  tty_$xon_xoff_handler_t =
    ^procedure(line_id: integer32; stop: boolean); options(val_param);
  tty_$flow_ctrl_handler_t =
    ^procedure(line_id: integer32; assert_flow: boolean;
               use_hw_flow: boolean); options(val_param);
  tty_$status_handler_t =
    ^function(line_id: integer32; clear: boolean): integer32;
      options(val_param);

  { The transmit callback, called with the line id by value as a longword
    (tty_$i_put_chars). }
  tty_$xmit_callback_t =
    ^procedure(line_id: integer32); options(val_param);

  { The characters tty_$i_put_chars takes, as an `in' `univ' array (ref
    5.3.3): one character, indexed beyond its bound for a buffer of any
    length (the kernel has no bounds checks), the old Pascal idiom.
    Its callers pass a char variable, a one-character constant, a
    one-byte temporary or a caller's buffer; a longer formal would need
    longer temporaries and cells. }
  tty_$chars_t = array[1..1] of char;

  { The descriptor of one line, 0x4DC bytes.  The pointers whose targets
    have no Pascal type yet are univ_ptr; input_ec and output_ec point
    to eventcounts.

    The fields that Apollo's types cover:
    - output_flags, raw_saved_output_flags, input_flags,
      raw_saved_input_flags, echo_flags and func_enabled are 32-member
      sets ("Types" above); func_enabled has a member per function slot.
    - func_chars, 18 bytes at 0x24..0x35, one character per slot,
      indexed by tty_$func_erase .. tty_$func_reserved_18: that the
      kernel stores 18 slots and not 32 is the image's.
    - delay, 5 words at 0x40..0x49, indexed tty_$delay_nl ..
      tty_$delay_ff, each a pinteger.
    - break_mode, 8 bytes at 0x38..0x3F, one tty_$input_break_mode_t:
      type 0, tty_$break_on_eol, is line mode; raw mode is
      tty_$break_on_count with count 1; tty_$i_wait arms its timer for
      tty_$break_on_timer and tty_$break_on_timer_or_count.
    state_flags and pending_signal are kernel-internal (Apollo declares
    no type for them): tty_$flags16_t, with the tty_$st_* and tty_$err_*
    numbers above. }
  tty_$desc_t = record
    line_id: integer32;                   { 0x000 }
    handler_ptr: univ_ptr;                { 0x004 }
    state_flags: tty_$flags16_t;          { 0x008: tty_$st_* }
    pending_signal: tty_$flags16_t;       { 0x00A: tty_$err_* }
    output_flags: tty_$output_flag_set_t; { 0x00C }
    raw_saved_output_flags: tty_$output_flag_set_t; { 0x010 }
    input_flags: tty_$input_flag_set_t;   { 0x014 }
    raw_saved_input_flags: tty_$input_flag_set_t;   { 0x018 }
    echo_flags: tty_$echo_flag_set_t;     { 0x01C }
    func_enabled: tty_$func_set_t;        { 0x020: one member per slot }
    func_chars: array[tty_$func_erase..tty_$func_reserved_18] of char;
                                          { 0x024: 18 slots }
    reserved_36: integer;                 { 0x036 }
    break_mode: tty_$input_break_mode_t;  { 0x038: break_type 0x38,
                                            count 0x3A, timer 0x3C }
    delay: array[tty_$delay_nl..tty_$delay_ff] of pinteger;
                                          { 0x040: 5 words }
    reserved_4a: integer;                 { 0x04A }
    pgroup_uid: uid_$t;                   { 0x04C }
    session_id: integer;                  { 0x054 }
    saved_input_flags: integer;           { 0x056 }
    column: integer;                      { 0x058 }
    reserved_5a: integer;                 { 0x05A }
    signals: array[0..5] of tty_$signal_entry_t;  { 0x05C }
    char_class: array[char] of integer;   { 0x0A4: tty_$class_* }
    input_ec: ec_$eventcount_ptr_t;       { 0x2A4 }
    output_ec: ec_$eventcount_ptr_t;      { 0x2A8 }
    reserved_2ac: univ_ptr;               { 0x2AC }
    err_handler: univ_ptr;                { 0x2B0 }
    xmit_callback: tty_$xmit_callback_t;  { 0x2B4 }
    xon_xoff_handler: tty_$xon_xoff_handler_t;    { 0x2B8 }
    flow_ctrl_handler: tty_$flow_ctrl_handler_t;  { 0x2BC }
    status_handler: tty_$status_handler_t;        { 0x2C0 }
    last_input_clock: time_$clock_t;      { 0x2C4: written by TIME_$CLOCK }
    input_head: tty_$buf_pos_t;           { 0x2CA: end of committed input }
    input: tty_$cbuf_t;                   { 0x2CC..0x3D1 }
    output: tty_$cbuf_t;                  { 0x3D2..0x4D7 }
    crash_char: char;                     { 0x4D8 }
    raw_mode: boolean;                    { 0x4D9 }
    reserved_4da: integer;                { 0x4DA }
  end;

{ Routine headings: the TTY routines that are global symbols in the SAU2
  map, in map order.  The modules repeat the full heading on the body
  (ref 7.3.4, Method 2, with the parameter list repeated, as ref 5.5.2
  allows for forward routines).  Module-local routines are declared in
  the module that holds them. }

{ TTY_$I_OUTPUT_BUFFER_DRAINED - the output buffer has drained: wake the
  writers. }
procedure tty_$i_output_buffer_drained(in out tty: tty_$desc_t); extern;

{ TTY_$I_FLUSH_INPUT - discard all buffered input. }
procedure tty_$i_flush_input(in out tty: tty_$desc_t); extern;

{ TTY_$I_FLUSH_OUTPUT - discard all buffered output. }
procedure tty_$i_flush_output(in out tty: tty_$desc_t); extern;

{ TTY_$I_SIGNAL - queue a signal for the line's process group. }
procedure tty_$i_signal(var tty: tty_$desc_t; signal: integer);
  options(extern, val_param);

{ TTY_$I_RCV - take one received character: classify it and act on its
  class. }
procedure tty_$i_rcv(var tty: tty_$desc_t; ch: char);
  options(extern, val_param);

{ TTY_$I_ERR - take a receive error: store a marker in the input, or flag
  the error and wake the waiters. }
procedure tty_$i_err(var tty: tty_$desc_t; ch: char);
  options(extern, val_param);

{ TTY_$I_INTERRUPT - the line's interrupt condition: flush the input and
  signal SIGINT. }
procedure tty_$i_interrupt(var tty: tty_$desc_t); extern;

{ TTY_$I_HUP - the line's hangup condition: forget the session, flush both
  directions and signal SIGHUP and SIGCONT. }
procedure tty_$i_hup(var tty: tty_$desc_t); extern;

{ TTY_$K_FLUSH_INPUT - discard a line's buffered input, for a caller of
  the kernel interface.
  TTY_$K_FLUSH_OUTPUT - discard a line's buffered output, for a caller of
  the kernel interface. }
procedure tty_$k_flush_input(in line: integer; out status: status_$t);
  extern;
procedure tty_$k_flush_output(in line: integer; out status: status_$t);
  extern;

{ TTY_$K_SIMULATE_TERMINAL_INPUT - feed one character to a line as if it
  had been received, for a caller of the kernel interface. }
procedure tty_$k_simulate_terminal_input(in line: integer; in ch: char;
                                         out status: status_$t);
  extern;

{ TTY_$K_GET - read characters from a line's input, for a caller of the
  kernel interface. }
function tty_$k_get(in line: integer; in options: tty_$flags16_t;
                    out buffer: univ tty_$chars_t; in count: tty_$uword_t;
                    out status: status_$t): tty_$uword_t;
  extern;

{ TTY_$I_INIT - set up a line's descriptor. }
procedure tty_$i_init(var tty: tty_$desc_t); extern;

{ TTY_$I_GET_DESC - the TTY descriptor of a terminal line. }
function tty_$i_get_desc(line: integer; out status: status_$t):
  integer32; options(extern, val_param, a0_return);

{ TTY_$I_DXM_SIGNAL - send a queued line signal to the line's process
  group. }
procedure tty_$i_dxm_signal(in entry_ptr: tty_$signal_entry_ptr_t); extern;

{ TTY_$I_ENABLE_CRASH_FUNC - make a character the line's crash character,
  or stop having one. }
procedure tty_$i_enable_crash_func(in out tty: tty_$desc_t; ch: char;
                                   enable: boolean);
  options(extern, val_param);

{ TTY_$K_RESET - reset a line's buffers, process group and delays, for a
  caller of the kernel interface. }
procedure tty_$k_reset(in line: integer; out status: status_$t); extern;

{ TTY_$I_SET_RAW - switch a line into or out of raw mode, by line number. }
procedure tty_$i_set_raw(line: integer; raw: boolean; out status: status_$t);
  options(extern, val_param);

{ TTY_$I_INQ_RAW - whether a line is in raw mode, by line number. }
procedure tty_$i_inq_raw(line: integer; out raw: boolean;
                         out status: status_$t);
  options(extern, val_param);

{ TTY_$K_SET_FLAG - turn a line's signal on input on or off, for a caller
  of the kernel interface. }
procedure tty_$k_set_flag(in line: integer; in flag: integer;
                          in value: boolean; out status: status_$t);
  extern;

{ TTY_$K_INQ_FLAGS - whether a line's signal on input is on, for a caller
  of the kernel interface. }
procedure tty_$k_inq_flags(in line: integer; out flags: tty_$flags16_t;
                           out status: status_$t);
  extern;

{ TTY_$K_SET_FUNC_CHAR - bind a function slot of a line to a character,
  for a caller of the kernel interface. }
procedure tty_$k_set_func_char(in line: integer; in func: tty_$func_t;
                               in ch: char; out status: status_$t);
  extern;

{ TTY_$K_INQ_FUNC_CHAR - the character bound to a function slot of a line,
  for a caller of the kernel interface. }
procedure tty_$k_inq_func_char(in line: integer; in func: tty_$func_t;
                               out ch: char; out status: status_$t);
  extern;

{ TTY_$K_ENABLE_FUNC - enable or disable a function slot of a line, for a
  caller of the kernel interface. }
procedure tty_$k_enable_func(in line: integer; in func: tty_$func_t;
                             in enable: boolean; out status: status_$t);
  extern;

{ TTY_$K_INQ_FUNC_ENABLED - the enabled function slots of a line, for a
  caller of the kernel interface. }
procedure tty_$k_inq_func_enabled(in line: integer;
                                  out enabled: tty_$func_set_t;
                                  out status: status_$t);
  extern;

{ TTY_$K_SET_INPUT_FLAG - turn one input flag of a line on or off, for a
  caller of the kernel interface. }
procedure tty_$k_set_input_flag(in line: integer;
                                in flag: tty_$input_flag_t;
                                in value: boolean; out status: status_$t);
  extern;

{ TTY_$K_INQ_INPUT_FLAGS - the input flags of a line, for a caller of the
  kernel interface. }
procedure tty_$k_inq_input_flags(in line: integer;
                                 out flags: tty_$input_flag_set_t;
                                 out status: status_$t);
  extern;

{ TTY_$K_SET_OUTPUT_FLAG - turn one output flag of a line on or off, for a
  caller of the kernel interface. }
procedure tty_$k_set_output_flag(in line: integer;
                                 in flag: tty_$output_flag_t;
                                 in value: boolean; out status: status_$t);
  extern;

{ TTY_$K_INQ_OUTPUT_FLAGS - the output flags of a line, for a caller of
  the kernel interface. }
procedure tty_$k_inq_output_flags(in line: integer;
                                  out flags: tty_$output_flag_set_t;
                                  out status: status_$t);
  extern;

{ TTY_$K_SET_ECHO_FLAG - turn one echo flag of a line on or off, for a
  caller of the kernel interface. }
procedure tty_$k_set_echo_flag(in line: integer;
                               in flag: tty_$echo_flag_t;
                               in value: boolean; out status: status_$t);
  extern;

{ TTY_$K_INQ_ECHO_FLAGS - the echo flags of a line, for a caller of the
  kernel interface. }
procedure tty_$k_inq_echo_flags(in line: integer;
                                out flags: tty_$echo_flag_set_t;
                                out status: status_$t);
  extern;

{ TTY_$K_SET_INPUT_BREAK_MODE - set a line's input break mode, for a
  caller of the kernel interface. }
procedure tty_$k_set_input_break_mode(in line: integer;
                                      in mode: tty_$input_break_mode_t;
                                      out status: status_$t);
  extern;

{ TTY_$K_INQ_INPUT_BREAK_MODE - a line's input break mode, for a caller of
  the kernel interface. }
procedure tty_$k_inq_input_break_mode(in line: integer;
                                      out mode: tty_$input_break_mode_t;
                                      out status: status_$t);
  extern;

{ TTY_$K_SET_PGROUP - set the process group of a line, for a caller of the
  kernel interface. }
procedure tty_$k_set_pgroup(in line: integer; in uid: uid_$t;
                            out status: status_$t);
  extern;

{ TTY_$K_INQ_PGROUP - the process group of a line, for a caller of the
  kernel interface. }
procedure tty_$k_inq_pgroup(in line: integer; out uid: uid_$t;
                            out status: status_$t);
  extern;

{ TTY_$K_SET_SESSION_ID - set the session id of a line, for a caller of
  the kernel interface. }
procedure tty_$k_set_session_id(in line: integer; in sid: integer;
                                out status: status_$t);
  extern;

{ TTY_$K_INQ_SESSION_ID - the session id of a line, for a caller of the
  kernel interface. }
procedure tty_$k_inq_session_id(in line: integer; out sid: integer;
                                out status: status_$t);
  extern;

{ TTY_$K_SET_DELAY - set one of a line's output delays, for a caller of
  the kernel interface. }
procedure tty_$k_set_delay(in line: integer; in delay: tty_$delay_t;
                           in val: pinteger; out status: status_$t);
  extern;

{ TTY_$K_INQ_DELAY - one of a line's output delays, for a caller of the
  kernel interface. }
procedure tty_$k_inq_delay(in line: integer; in delay: tty_$delay_t;
                           out val: pinteger; out status: status_$t);
  extern;

{ TTY_$K_DRAIN_OUTPUT - wait until a line's output buffer is empty, for a
  caller of the kernel interface. }
procedure tty_$k_drain_output(in line: integer; out status: status_$t);
  extern;

{ TTY_$K_PUT - write characters to a line's output, for a caller of the
  kernel interface. }
procedure tty_$k_put(in line: integer; in options: tty_$flags16_t;
                     in buffer: univ tty_$chars_t;
                     in out count: tty_$uword_t; out status: status_$t);
  extern;
