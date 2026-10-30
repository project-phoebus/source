{ dtty/dtty.ins.pas - the display TTY (DTTY_), for the Domain Pascal
  tree.

  Holds only what the Pascal files use: the line record DTTY_$TSTART is
  called with, the module's map-named variables and the headings of the
  map-global routines, compiled (dtty/dtty.pas) and hand-written
  (DTTY_WIRED, DTTY_ASM).  No customer insert file declares these.
  Include base/base.ins.pas before it.
}

type
  { The characters DTTY_$WRITE_STRING writes, an `in' `univ' array of
    one element indexed beyond its bound: tty/tty.ins.pas tty_$chars_t's
    idiom (the kernel has no bounds checks).  DTTY_$WRITE_STRING reaches
    character i at the slot's address + i - 1: a 1-based array of bytes. }
  dtty_$chars_t = array[1..1] of char;

  { The output buffer DTTY_$TSTART drains: the word at 0 is where output
    resumes, the word at 2 how far it goes, the word at 4 the buffer's
    last position; the characters from 6, 1-based.  The words are
    compared unsigned: pinteger.  The third field is end_pos (`end' is a
    reserved word).  The layout is TTY's circular buffer's
    (tty/tty.ins.pas tty_$cbuf_t: head, tail, size, data). }
  dtty_buffer_t = record
    current: pinteger;                    { 0x00 }
    target: pinteger;                     { 0x02 }
    end_pos: pinteger;                    { 0x04 }
    data: dtty_$chars_t;                  { 0x06 }
  end;
  dtty_buffer_ptr_t = ^dtty_buffer_t;

  { The routine DTTY_$TSTART calls when it has written the buffer, with
    the record's second longword by value. }
  dtty_tstart_callback_t = ^procedure(arg: univ_ptr); options(val_param);

  { The record DTTY_$TSTART is called with: the callback at 0, its
    argument at 4, the buffer's address at 8. }
  dtty_tstart_t = record
    callback: dtty_tstart_callback_t;     { 0x00 }
    callback_arg: univ_ptr;               { 0x04 }
    buffer_info: dtty_buffer_ptr_t;       { 0x08 }
  end;
  dtty_tstart_ptr_t = ^dtty_tstart_t;

var
  { DTTY_$CTRL, a map symbol in DTTY's data block (+0x02), defined by
    dtty/dtty.pas.  DTTY_$INIT stores the caller's control word there
    and later 0: a word, integer (no reader in the SAU2 image). }
  dtty_$ctrl: extern integer;

  { DTTY_$USE_DTTY, a map symbol in DTTY's data block (+0x08): true
    (16#FF) when the display TTY is used.  Compiled code tests it by its
    sign (TTY_$I_GET_DESC): a boolean, another unit's variable read at
    its absolute address.  dtty/dtty.pas defines it. }
  dtty_$use_dtty: extern boolean;

  { DTTY_$STD_FONT_P (map symbol, in the hand-written DTTY_ASM data
    segment, 0x44C bytes): a pointer, DTTY_$FONT1's address, after
    DTTY_$ESCAPE's two instructions.  DTTY_$INIT and DTTY_$RELOAD_FONT
    pass it by address to dtty_$load_font, which hands it to
    SMD_$COPY_FONT_TO_MD_HDM, which reads the pointer.  univ_ptr: the
    font has no Pascal type. }
  dtty_$std_font_p: extern univ_ptr;

{ The compiled routines (dtty/dtty.pas), in map order. }

{ DTTY_$WRITE_STRING - write characters to the display through the PROM. }
procedure dtty_$write_string(in str: univ dtty_$chars_t; in len: integer);
  extern;

{ DTTY_$TSTART - drain a line's output buffer to the display. }
procedure dtty_$tstart(tstart: dtty_tstart_ptr_t); options(extern, val_param);

{ DTTY_$RELOAD_FONT - copy the standard font into the display's hidden
  memory again. }
procedure dtty_$reload_font; extern;

{ DTTY_$INIT - set up the display TTY. }
procedure dtty_$init(in mode: integer; in ctrl: integer); extern;

{ The hand-written routines (the map's DTTY_WIRED segment, 0x48 bytes
  in WIRED_DATA: dtty/m68k/prom_io.s, dtty/README.md). }

{ DTTY_$PUTC: the character's address read off the stack above nine
  saved registers: by address.  DTTY_$WRITE_STRING pushes the
  character's address. }
procedure dtty_$putc(in ch: char); extern;
