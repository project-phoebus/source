{ term/os_term_init.pas - the OS_TERM_INIT module, the terminal lines'
  records and their set-up.

  Image addresses:
    sau2  0x00E2C9F0  OS_TERM_INIT data (WIRED_DATA, 0x1398 bytes)
    sau2  0x00E35154  OS_TERM_INIT data (OS_INIT_DATA, 0x5C bytes)
    sau9  0x3C43178C  OS_TERM_INIT data (WIRED_DATA, 0x1A8C bytes)

  One compilation unit, `module os_term_init, wired_proc, wired_data;':
  the map's OS_TERM_INIT code segments in WIRED_PROC (KBD_$RESET ..
  TONE_$ENABLE), OS_INIT_PROC (five module-local routines, SIO_$INIT,
  TERM_$INIT), PROCEDURE$ (TERM_$PCHIST_ENABLE, TERM_$ENQUEUE_TPAD) and
  PROC2_DELETE_PRO (TERM_$P2_CLEANUP), each headed with its sections.

  The data: WIRED_DATA (5016 bytes; 6796 with `sio16550_lines') holds the
  lines' records, handler blocks and parameters, DTTE, TTY_$SPIN_LOCK
  and TERM_$MAX_DTTE, each declared below with its offset; the
  OS_INIT_DATA block (92 bytes) is TERM_$INIT's statics, which the
  `sio16550_lines' form does not have.

  With `sio16550_lines' there are four serial lines, each line's
  descriptors set up by SIO_$INIT as the serial driver starts its port,
  and the console's channel is the 16550's; the SIO6509 and SIO2681
  records are absent.

  The routines live in one fragment file each, included below in image
  order with the other subsystems' routines of the segments
  (kbd/reset.pas, tone/enable.pas, sio/init*.pas, os/term_init.pas).

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/term/os_term_init.pas.  Check: tools/pascal_check.sh.
}
module os_term_init, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ml/ml.ins.pas';
%include 'ec/ec.ins.pas';
%include 'dxm/dxm.ins.pas';
%include 'time/time.ins.pas';
%include 'cal/cal.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'fim/fim.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'sio/sio.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'tty/tty.ins.pas';
%include 'smd/smd.ins.pas';
%include 'suma/suma.ins.pas';
%include 'term/term.ins.pas';
%include 'kbd/kbd.ins.pas';
%include 'dtty/dtty.ins.pas';
%include 'tpad/tpad.ins.pas';
%include 'sio2681/sio2681.ins.pas';
%include 'sio6509/sio6509.ins.pas';
%include 'tone/tone.ins.pas';
%if sio16550_lines %then
%include 'io/io.ins.pas';
%include 'sio16550/sio16550.ins.pas';
%endif

const
  { The serial lines' TTY and SIO descriptors (the console's is the
    first): TERM_$P2_CLEANUP's count. }
%if sio16550_lines %then
  term_$n_lines = 4;
%else
  term_$n_lines = 3;
%endif

type
  { The handler blocks: 10, 6 and 4 handler addresses (above). }
  term_$handlers_t = array[1..10] of univ_ptr;
  term_$line_handlers_t = array[1..6] of univ_ptr;
  term_$kbd_handlers_t = array[1..4] of univ_ptr;
  { The same 16 bytes as os_term_init sees them: the first entry, then
      the three it copies whole into the keyboard descriptor's +0x04
      (os/term_init.pas). }
  term_$kbd_handlers_view_t = record
    first: univ_ptr;                      { 0x00 }
    rest: kbd_$handler_block_t;           { 0x04 }
  end;
  { TERM_$INIT's two driver tables (term/init.pas): 10 and 9 entries. }
  term_$vtable_t = array[1..10] of univ_ptr;
  term_$serial_vtable_t = array[1..9] of univ_ptr;

{ The module's variables and the globals it defines (ref 7.2.2 and 7.3.4,
  Method 2), in the order of the block. }
var
  term_$serial_params: sio_$params_t :=
    [flags1 := [0, 3], flags2 := [2, 3], break_mask := [],
     baud_rate := [tx := 16#E, rx := 16#E], char_size := 3, stop_bits := 1,
     parity := 0];                                        { +0x0000 }
  term_$tty_handlers: term_$handlers_t :=
    [addr(tty_$i_rcv), addr(tty_$i_output_buffer_drained), addr(tty_$i_hup),
     addr(tty_$i_interrupt), addr(tty_$i_err), nil, nil, nil, nil, nil];
                                                          { +0x0018 }
  term_$serial_line_handlers: term_$line_handlers_t :=
    [nil, nil, addr(sio_$i_tstart), addr(sio_$i_inhibit_xmit),
     addr(sio_$i_inhibit_rcv), addr(sio_$i_err)];         { +0x0040 }
  term_$console_params: sio_$params_t :=
    [flags1 := [0, 3], flags2 := [], break_mask := [],
     baud_rate := [tx := 7, rx := 7], char_size := 3, stop_bits := 1,
     parity := 3];                                        { +0x0058 }
  term_$console_line_handlers: term_$line_handlers_t :=
    [nil, nil, addr(dtty_$tstart), nil, nil, nil];        { +0x0070 }
  term_$console_handlers: term_$handlers_t :=
    [addr(kbd_$rcv), addr(kbd_$output_buffer_drained), nil, nil, nil, nil,
     nil, nil, nil, nil];                                 { +0x0088 }
  term_$kbd_handlers: term_$kbd_handlers_t :=
    [nil, addr(sio_$i_tstart), nil, nil];                 { +0x00B0 }
  term_$kbd_rcv: univ_ptr := addr(tty_$i_rcv);            { +0x00C0 }
%if sio16550_lines %then
  unused_0c4: array[1..188] of char;                      { +0x00C4, zero }
  tty_descs: array[1..term_$n_lines] of tty_$desc_t;      { +0x0180, zero }
  sio_descs: array[1..term_$n_lines] of sio_$desc_t;      { +0x14F0, zero }
  term_$console_drain: array[1..1] of dtty_tstart_t;      { +0x16D0, zero }
  unused_16dc: integer32;                                 { +0x16DC, zero }
  kbd_descs: array[1..1] of kbd_$desc_t;                  { +0x16E0, zero }
  unused_1984: integer32;                                 { +0x1984, zero }
%else
  unused_0c4: array[1..148] of char;                      { +0x00C4, zero }
  tty_descs: array[1..term_$n_lines] of tty_$desc_t;      { +0x0158, zero }
  unused_fec: integer32;                                  { +0x0FEC, zero }
  sio_descs: array[1..term_$n_lines] of sio_$desc_t;      { +0x0FF0, zero }
  term_$console_drain: array[1..1] of dtty_tstart_t;      { +0x1158, zero }
  unused_1164: integer32;                                 { +0x1164, zero }
  kbd_descs: array[1..1] of kbd_$desc_t;                  { +0x1168, zero }
  unused_124c: integer32;                                 { +0x124C, zero }
  term_$console_chan: sio6509_$chan_t;                    { +0x1250, zero }
  term_$sio2681_chip: sio2681_$chip_t;                    { +0x1258, zero }
  unused_1264: integer32;                                 { +0x1264, zero }
  tone_$channel: sio2681_$channel_t;                      { +0x1268, zero }
  term_$serial_chan_b: sio2681_$channel_t;                { +0x1284, zero }
%endif

{ The offsets below are the `sio16550_lines' form's in parentheses. }

define
  dtte;                                         { +0x12A0 (+0x1988), zero }

var
  unused_1380: integer32;                       { +0x1380 (+0x1A68), zero }
%if sio16550_lines %then
  { The console's 16550 channel: SIO_$INIT records it, KBD_$RESET writes
    the keyboard's reset bytes through it. }
  term_$console_chan_ptr: sio16550_$chan_ptr_t; {         (+0x1A6C), zero }
%endif

define
  tty_$spin_lock;                               { +0x1384 (+0x1A70), zero }

%if sio16550_lines %then
var
  unused_1a74: integer;                         {         (+0x1A74), zero }
%endif

define
  term_$max_dtte;                               { +0x1388 (+0x1A76), zero }

var
%if not sio16550_lines %then
  unused_138a: integer;                         { +0x138A, zero }
%endif
  { The two bytes KBD_$RESET sends the keyboard, each the low byte of
    its word. }
  kbd_$reset_bytes: array[1..2] of integer := [16#FF, 0];
                                                { +0x138C (+0x1A78) }
  { The keyboard string TERM_$SET_REAL_LINE_DISCIPLINE sends (its first
    5 bytes). }
  term_$kbd_string: array[1..6] of char :=
    [chr(16#FF), chr(0), chr(16#FF), chr(16#12), chr(16#21), chr(0)];
                                                { +0x1390 (+0x1A7C) }
%if kbd_tone %then
  { The keyboard's tone commands, TONE_$ENABLE's. }
  tone_$off_string: array[1..3] of char :=
    [chr(16#FF), chr(16#21), chr(16#82)];       {         (+0x1A82) }
  tone_$on_string: array[1..3] of char :=
    [chr(16#FF), chr(16#21), chr(16#81)];       {         (+0x1A86) }
%endif

{ TODO(pascal) OS_TERM_INIT's block has bytes no instruction reaches

  unused_0c4 (0x94 bytes at +0xC4, 0xBC with `sio16550_lines') and the
  longwords at +0xFEC, +0x1164, +0x124C, +0x1264 and +0x1380 (+0x16DC,
  +0x1984, +0x1A68; and the word at +0x1A74) are reached by no code in
  the SAU2 and SAU9 images (the module's A5 and absolute operands, a
  byte search for the block's addresses).  The longwords before
  8-aligned objects of 8 bytes or more (+0xFF0, +0x1168, +0x1250,
  +0x1268; +0x16E0, +0x1988) fit an 8-byte alignment; but
  term_$serial_chan_b at +0x1284 is not 8-aligned after them, and
  +0x1380, before a 4-byte object, is not explained by it.  The first
  block may be a record not yet identified. }

define
  kbd_$reset;
  term_$set_discipline;
  term_$set_real_line_discipline;
  term_$inq_discipline;
  tone_$enable;
  term_$init;
  term_$pchist_enable;
  term_$enqueue_tpad;
  term_$p2_cleanup;
  sio_$init;

{ Module-local routines called before their bodies, or whose bodies are
  not written yet (ref 5.5.2; the `body:' lines let tools/pascal_check.sh
  make a heading `extern' while its fragment is missing).  Each is
  `internal' (no map symbol; each has the reserved slot), and each
  pointer argument TERM_$INIT passes by address, a local or an `addr'
  expression's temporary (term/init.pas), so those formals are `univ'
  (ref 5.2, Table 5-1: `univ' cancels the by-value passing of `internal'
  for 4-byte `in' formals; an expression cannot go to `var').  The
  records are `var', written through their slots; the handler blocks and
  the parameter block `in' (more than 4 bytes, by address).  Evidence
  from the bodies:

  os_term_init: writes the keyboard descriptor, passes it to KBD_$INIT,
  stores its address into the DTTE, and the DTTE's into it; reads the
  three pointer cells, and three longwords of the handler block from +4.
  Those three are one 12-byte block copy, so the handler block's formal
  is `univ term_$kbd_handlers_view_t' (the first entry, then a 12-byte
  field); its callers' arguments, term_$kbd_handlers itself, pass
  unchanged. }
{ body: os/term_init.pas }
procedure os_term_init(var kbd: kbd_$desc_t; var dtte: dtte_t;
                       in tty: univ univ_ptr; in rcv: univ univ_ptr;
                       in sio: univ univ_ptr;
                       in handlers: univ term_$kbd_handlers_view_t);
  forward; internal;

{ sio_$init_desc: writes the SIO descriptor, its parameter block copied
  from the second argument, its four handlers from the sixth, its four
  driver entries from the eighth's +0x14; reads the three pointer cells;
  stores the descriptor's address into the DTTE, and passes it to SIO. }
{ body: sio/init_desc.pas }
procedure sio_$init_desc(var desc: sio_$desc_t; in params: sio_$params_t;
                         var dtte: dtte_t; in owner: univ univ_ptr;
                         in txbuf: univ univ_ptr;
                         in handlers: univ sio_$handlers_t;
                         in context: univ univ_ptr;
                         in vtable: univ sio_$vtable_t);
  forward; internal;

{ sio_$init_line: writes the TTY descriptor (its handlers from the
  fourth argument's +8, the DTTE's two eventcounts' addresses), passes
  it to TTY_$I_INIT and stores its address into the DTTE. }
{ body: sio/init_line.pas }
procedure sio_$init_line(var tty: tty_$desc_t; var dtte: dtte_t;
                         in context: univ univ_ptr;
                         in handlers: univ sio_$line_handlers_t);
  forward; internal;

{ sio_$init_dtte: the DTTE by address, its three eventcounts to EC_$INIT,
  the discipline a word by value, stored at +0x34. }
{ body: sio/init_dtte.pas }
procedure sio_$init_dtte(var dtte: dtte_t; discipline: integer);
  forward; internal;

{ sio_$init_drain_handler: writes the drain record (the buffer,
  TTY_$I_OUTPUT_BUFFER_DRAINED, the owner); its second argument is not
  read. }
{ body: sio/init_drain_handler.pas }
procedure sio_$init_drain_handler(var drain: dtty_tstart_t; var dtte: dtte_t;
                                  in buffer: univ univ_ptr;
                                  in owner: univ univ_ptr);
  forward; internal;

{ The module-local SIO and OS routines' pointer formals (settled by SIO's
  translation, which wrote the four SIO bodies; it was an open item of
  TERM's).  TERM_$INIT and SIO_$INIT pass these routines pointer values
  by address, from pointer locals and from `addr' expressions: the
  expressions' temporaries are stored between the pushes, where a
  statement assigning a local would come before the call's first push;
  and SIO_$INIT passes its own by-address parameters on as they are.  So
  the formals take expressions: value or `in' formals, not `var'.  The
  routines are `internal' (no map symbol; a routine of a module that is
  not `internal' is a global symbol, ref 7.3, "By default, all routine
  names in modules are global symbols"), under which a 4-byte `in' or
  value formal is passed by value unless it is `univ' (ref 5.2, Table
  5-1).  The bodies read each through its slot: `in ... univ'.  What
  type the original named for them under `univ' is not known (univ_ptr
  here). }

{ ---- WIRED_PROC ---- }
%include 'kbd/reset.pas';                   { KBD_$RESET }
%include 'term/set_discipline.pas';         { TERM_$SET_DISCIPLINE }
%include 'term/set_real_line_discipline.pas';
                                            { TERM_$SET_REAL_LINE_DISCIPLINE }
%include 'term/inq_discipline.pas';         { TERM_$INQ_DISCIPLINE }
%include 'tone/enable.pas';                 { TONE_$ENABLE }

{ ---- OS_INIT_PROC ---- }
%include 'os/term_init.pas';                { os_term_init }
%include 'sio/init_desc.pas';               { sio_$init_desc }
%include 'sio/init_line.pas';               { sio_$init_line }
%include 'sio/init_dtte.pas';               { sio_$init_dtte }
%include 'sio/init_drain_handler.pas';      { sio_$init_drain_handler }
%include 'sio/init.pas';                    { SIO_$INIT }
%include 'term/init.pas';                   { TERM_$INIT }

{ ---- PROCEDURE$ ---- }
%include 'term/pchist_enable.pas';          { TERM_$PCHIST_ENABLE }
%include 'term/enqueue_tpad.pas';           { TERM_$ENQUEUE_TPAD }

{ ---- PROC2_DELETE_PRO ---- }
%include 'term/p2_cleanup.pas';             { TERM_$P2_CLEANUP }