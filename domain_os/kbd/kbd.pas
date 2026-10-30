{ kbd/kbd.pas - the KBD module, the keyboard driver.

  Image addresses:
    sau2  0x00E2DDE4  KBD data (WIRED_DATA, 0xD4 bytes)
    sau9  0x3C433274  KBD data (WIRED_DATA, 0x108 bytes)
    sau9  0x3C49E084  KBD data (DATA$, 0x14 bytes)

  One compilation unit, in three code sections and one data section: the
  map's KBD code segments in WIRED_PROC (0x4F0 bytes), OS_INIT_PROC (0x78)
  and PROCEDURE$ (0xEC), and its KBD data segment in WIRED_DATA (0xD4
  bytes, with the map symbol TERM_$TPAD_BUFFER inside).  The third code
  segment is in PROCEDURE$, not .TEXT, so it is a named section here.
  With `kbd_commands' (base/config.ins.pas) the segments are 0x6FC,
  0x8C and 0x16C bytes, the data 0x108, and a second data segment in
  DATA$ (0x14 bytes) holds KBD_$GET_CHAR_AND_MODE's static command.

  Why one module: routines with no global symbol are called across the
  sections (kbd_$set_type, kbd_$fetch_key), and an internal routine can
  only be called from its own compilation unit (ref 5.2, 5.5.4).  The
  map gives the four segments one module name, KBD.

  The data, 0xD4 bytes (0x108 with `kbd_commands'):

    +0x00  kbd_$mode_table     8     kbd_$get_mode, _$GET_CHAR_AND_MODE
    +0x08  kbd_$escape_state   0x10  kbd_$fetch_key, KBD_$RCV
    +0x18  kbd_$state_range    0x40  kbd_$state_lookup
    +0x58  term_$tpad_buffer   0x64  defined (map symbol)
    +0xBC  kbd_$console_desc   4     KBD_$INIT, KBD_$CRASH_INIT
    +0xC0  kbd_$state_table    0x14  kbd_$state_lookup (0x48 with
                                     `kbd_commands')

  These are module variables (TTY's model, tty/tty.pas), in WIRED_DATA:
  so the heading names wired_proc and wired_data, as LOG's (log/log.pas).
  KBD_$INIT is headed `[section(os_init_proc, os_init_data)]' and the
  PROCEDURE$ routines `[section(procedure$, data$)]' (ref 5.7.1): their
  data section is not WIRED_DATA, since they reach the block by its
  absolute address; their one static, with `kbd_commands', is in DATA$.

  The variables and the define'd one are interleaved in the block's
  order, as in log/log.pas (its TODO: the reference does not say where a
  variable declared extern and then defined is allocated).

  The routines live in one fragment file each (kbd/<name>.pas),
  included below in image order within each section; kbd_$put_line has
  a fragment of its own (kbd/README.md), and KBD_$RCV's nested
  routines are in kbd/rcv.pas.

  Build: dpc -I domain_os domain_os/kbd/kbd.pas.  Check:
  tools/pascal_check.sh.
}
module kbd, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'time/time.ins.pas';
%include 'dxm/dxm.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'smd/smd.ins.pas';
%include 'suma/suma.ins.pas';
%include 'term/term.ins.pas';
%include 'kbd/kbd.ins.pas';

{ The module's variables (ref 3.2.2 p. 3-4, 3.11.1: initial values of
  module variables), in the order of the block, and the global routines
  and the variable this module defines (ref 7.3.4 and 7.2.2, Method 2),
  in map order. }
var
  { +0x00: the mode codes kbd_$get_mode looks a key up in, and
    KBD_$GET_CHAR_AND_MODE maps a mode to (no map symbol, so not
    KBD_$'s).  Bytes compared with a key and stored as a character,
    indexed from 0 by a word: chars; eight, up to kbd_$escape_state. }
  kbd_$mode_table: array[0..7] of char := [
    chr(0), chr(1), chr(2), chr(3), chr(16#12), chr(16#10), chr(16#11),
    chr(16#0F)];
  { +0x08: the state a table entry whose next state is 15 leads to, by
    mode (kbd_$fetch_key) or by keyboard type (KBD_$RCV).  Words indexed
    from 0, scaled by 2: integer; eight, up to kbd_$state_range. }
  kbd_$escape_state: array[0..7] of integer := [
    0, 8, 6, 7, 14, 14, 14, 14];
  { +0x18: the (first, limit) pairs of the sixteen states, 0x40 bytes up
    to TERM_$TPAD_BUFFER. }
  kbd_$state_range: array[0..15] of kbd_$state_range_t := [
    [first := 0, limit := 5],             { state 0 }
    [first := 6, limit := 6],             { 1 }
    [first := 7, limit := 7],             { 2 }
    [first := 8, limit := 8],             { 3 }
    [first := 9, limit := 9],             { 4 }
    [first := 10, limit := 15],           { 5 }
    [first := 16, limit := 17],           { 6 }
    [first := 18, limit := 19],           { 7 }
    [first := 20, limit := 22],           { 8 }
    [first := 23, limit := 26],           { 9 }
    [first := 27, limit := 28],           { 10 }
    [first := 29, limit := 29],           { 11 }
    [first := 30, limit := 31],           { 12 }
    [first := 32, limit := 32],           { 13 }
    [first := 33, limit := 35],           { 14 }
    [first := 0, limit := 0]];            { 15 }

define
  term_$tpad_buffer;                      { +0x58..+0xBB, all zero }
  kbd_$rcv;
  kbd_$crash_init;
  kbd_$output_buffer_drained;
  kbd_$put;
  kbd_$init;
  kbd_$get_char_and_mode;
  kbd_$set_kbd_mode;
  kbd_$set_kbd_type;
  kbd_$inq_kbd_type;

var
  { +0xBC: the descriptor KBD_$INIT last set up, which KBD_$CRASH_INIT
    returns to the first mode; nil until then.  Only the `kbd_commands'
    form uses it (base/config.ins.pas); the other SAUs' blocks keep its
    4 bytes, zero. }
  kbd_$console_desc: kbd_$desc_ptr_t := nil;
  { +0xC0: the state machine's entries (key, action, next state), which
    kbd_$state_range indexes (entries 0 to 35). }
%if kbd_commands %then
  kbd_$state_table: array[0..35] of kbd_$state_entry_t := [
    [key := chr(16#FB), action := 2, next_state := 0],   { state 0 }
    [key := chr(16#E8), action := 3, next_state := 1],
    [key := chr(16#DF), action := 3, next_state := 1],
    [key := chr(16#FE), action := 11, next_state := 4],
    [key := chr(16#FF), action := 0, next_state := 5],
    [key := chr(0), action := 1, next_state := 0],       { its default }
    [key := chr(0), action := 4, next_state := 2],       { state 1's }
    [key := chr(0), action := 5, next_state := 3],       { state 2's }
    [key := chr(0), action := 6, next_state := 15],      { state 3's }
    [key := chr(0), action := 12, next_state := 0],      { state 4's }
    [key := chr(0), action := 7, next_state := 0],       { state 5 }
    [key := chr(1), action := 7, next_state := 8],
    [key := chr(2), action := 8, next_state := 6],
    [key := chr(3), action := 9, next_state := 7],
    [key := chr(16#12), action := 7, next_state := 10],
    [key := chr(0), action := 7, next_state := 14],      { its default }
    [key := chr(16#FF), action := 0, next_state := 5],   { state 6 }
    [key := chr(0), action := 4, next_state := 2],
    [key := chr(16#FF), action := 0, next_state := 5],   { state 7 }
    [key := chr(0), action := 4, next_state := 2],
    [key := chr(16#FF), action := 0, next_state := 5],   { state 8 }
    [key := chr(16#43), action := 1, next_state := 9],
    [key := chr(0), action := 1, next_state := 8],
    [key := chr(16#FF), action := 0, next_state := 5],   { state 9 }
    [key := chr(16#C3), action := 1, next_state := 8],
    [key := chr(16#52), action := 2, next_state := 9],
    [key := chr(0), action := 1, next_state := 9],
    [key := chr(16#21), action := 1, next_state := 11],  { state 10 }
    [key := chr(0), action := 1, next_state := 14],
    [key := chr(0), action := 13, next_state := 12],     { state 11's }
    [key := chr(16#2D), action := 1, next_state := 13],  { state 12 }
    [key := chr(0), action := 1, next_state := 14],
    [key := chr(0), action := 14, next_state := 14],     { state 13's }
    [key := chr(16#FF), action := 0, next_state := 5],   { state 14 }
    [key := chr(16#0D), action := 10, next_state := 14],
    [key := chr(0), action := 1, next_state := 14]];
%else
  { TODO(pascal) states 5..14 index past the table's end, into SIO_IO's block

    kbd_$state_range gives states 5 to 14 the entries 10 to 35, which
    lie past this array, in SIO_IO's block; kbd_$state_lookup indexes
    them unchecked.  States 6, 7, 8 and 14 are reachable:
    kbd_$escape_state leads to them for modes and keyboard types 1 to 7.
    Whether the source declared ten entries, as the map's 0xD4 bytes
    say, is not known; the bytes are the image's.  The `kbd_commands'
    form's block holds all 36. }
  kbd_$state_table: array[0..9] of kbd_$state_entry_t := [
    [key := chr(16#FB), action := 2, next_state := 0],
    [key := chr(16#E8), action := 3, next_state := 1],
    [key := chr(16#DF), action := 3, next_state := 1],
    [key := chr(16#FE), action := 11, next_state := 4],
    [key := chr(16#FF), action := 1, next_state := 0],
    [key := chr(0), action := 1, next_state := 0],   { state 0's default }
    [key := chr(0), action := 4, next_state := 2],   { state 1's }
    [key := chr(0), action := 5, next_state := 3],   { state 2's }
    [key := chr(0), action := 6, next_state := 15],  { state 3's }
    [key := chr(0), action := 12, next_state := 0]]; { state 4's }
%endif

{ ---- WIRED_PROC ---- }
%include 'kbd/state_lookup.pas';            { kbd_$state_lookup  }
%include 'kbd/get_mode.pas';                { kbd_$get_mode      }
%if kbd_commands %then
%include 'kbd/txbuf_put.pas';               { kbd_$txbuf_put     }
%endif
%include 'kbd/put_line.pas';                { kbd_$put_line      }
%include 'kbd/set_type.pas';                { kbd_$set_type      }
%if kbd_commands %then
%include 'kbd/send_mode.pas';               { kbd_$send_mode     }
%endif
%include 'kbd/fetch_key.pas';               { kbd_$fetch_key     }
%include 'kbd/rcv.pas';                     { KBD_$RCV, nested
                                              kbd_$process_key and
                                              kbd_$translate_key }
%include 'kbd/crash_init.pas';              { KBD_$CRASH_INIT    }
%include 'kbd/output_buffer_drained.pas';   { KBD_$OUTPUT_BUFFER_DRAINED }
%include 'kbd/put.pas';                     { KBD_$PUT           }

{ ---- OS_INIT_PROC ---- }
%include 'kbd/init.pas';                    { KBD_$INIT          }

{ ---- PROCEDURE$ ---- }
%include 'kbd/get_char_and_mode.pas';       { KBD_$GET_CHAR_AND_MODE }
%include 'kbd/set_kbd_mode.pas';            { KBD_$SET_KBD_MODE  }
%include 'kbd/set_kbd_type.pas';            { KBD_$SET_KBD_TYPE  }
%include 'kbd/inq_kbd_type.pas';            { KBD_$INQ_KBD_TYPE  }
