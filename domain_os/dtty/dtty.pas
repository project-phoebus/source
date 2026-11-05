{ dtty/dtty.pas - the DTTY module, the display TTY.

  Image addresses:
    sau2  0x00E2E00C  DTTY data (WIRED_DATA, 0xC bytes)
    sau3  0x00E2CB98  DTTY data (WIRED_DATA, 4 bytes)
    sau4  0x0F831144  DTTY data (WIRED_DATA, 0xC bytes)
    sau6  0x78032C28  DTTY data (WIRED_DATA, 0xC bytes)
    sau7  0x3C4359E0  DTTY data (WIRED_DATA, 0xC bytes)

  One compilation unit, in two code sections and one data section: the
  map's DTTY code segments in WIRED_PROC (0x1C8 bytes: four module-local
  routines, DTTY_$WRITE_STRING, DTTY_$TSTART, DTTY_$RELOAD_FONT) and in
  OS_INIT_PROC (0x15C bytes: DTTY_$INIT and its cells), and its DTTY
  data segment in WIRED_DATA (0xC bytes; DTTY_$CTRL, DTTY_$USE_DTTY).

  With `dtty_gpu' (the SAU6) the WIRED_PROC segment is 0x3AC bytes:
  six module-local routines, the graphics processor's command routine
  dtty_$gpu_command and its clear among them.

  Two more DTTY segments are hand-written, not this unit's
  (dtty/README.md): DTTY_WIRED (WIRED_DATA: DTTY_$PUTC,
  RELOAD_FONT, DTTY_$CLEAR_SCREEN, through PROM vectors) and DTTY_ASM
  (.DATA: DTTY_$ESCAPE, DTTY_$STD_FONT_P and the fonts).  Their headings
  are in dtty/dtty.ins.pas.

  Why one module with module variables: both code segments use the
  WIRED_DATA block, WIRED_PROC through A5, OS_INIT_PROC by the block's
  absolute address.  So the heading names wired_proc and wired_data,
  and DTTY_$INIT is headed `[section(os_init_proc, os_init_data)]'.

  The data, 0xC bytes, all zero in the image:

    +0x00  dtty_$disp_type    2  SMD_$INQ_DISP_TYPE's result
    +0x02  DTTY_$CTRL         2  the control word; map symbol
    +0x04  dtty_flag_04       1  a boolean, in a word
    +0x06  dtty_flag_06       1  a boolean, in a word
    +0x08  DTTY_$USE_DTTY     1  map symbol; TTY_$I_GET_DESC tests it
    +0x09  3 bytes: the bytes' words' low halves and the rounding to 4

  Without `display_driver' (the SAU3) the unit is DTTY_$INIT alone (0x1C
  bytes in OS_INIT_PROC; no WIRED_PROC code) and the block 4 bytes:
  DTTY_$CTRL at +0x00, DTTY_$USE_DTTY at +0x02.

  The defined variables are interleaved with the others in the block's
  order, as log/log.pas's (its TODO on where a defined extern variable
  is allocated applies).

  Build: dpc -I domain_os domain_os/dtty/dtty.pas.  Check:
  tools/pascal_check.sh.
}
module dtty, wired_proc, wired_data;

{ TODO(sau) the SAU5's WIRED_PROC routines

  The SAU5's DTTY WIRED_PROC segment (0x49C bytes) has both forms of
  the module-local routines: the color board's (`dtty_color_board')
  and the graphics processor's (`dtty_gpu'), seven routines, its
  dtty_$get_disp_type waiting for either and its
  dtty_$color_clear_window and dtty_$load_font choosing by
  SMD_$GRAPHIC_DEVICE_ID.  The SAU5's build has the SAU2's four. }

%include 'base/base.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'vfmt/vfmt.ins.pas';
%include 'smd/smd.ins.pas';
%include 'dtty/dtty.ins.pas';

{ The global routines this module defines (ref 7.3.4), in map order,
  and its variables in the order of the data block (above; ref 7.2.2,
  Method 2, for the defined ones). }
define
%if display_driver %then
  dtty_$write_string;
  dtty_$tstart;
  dtty_$reload_font;
%endif
  dtty_$init;

%if display_driver %then
var
  dtty_$disp_type: smd_$display_type_t;   { +0x00 }
%endif

define
  dtty_$ctrl;                             { +0x02 }

%if display_driver %then
var
  dtty_flag_04: boolean;                  { +0x04 }
  dtty_flag_06: boolean;                  { +0x06 }
%endif

define
  dtty_$use_dtty;                         { +0x08 }

const
  { The display unit DTTY_$INIT asks SMD_$INQ_DISP_TYPE about, a
    constant cell of DTTY_$INIT's. }
  dtty_display_unit = 1;

  { The second display unit, asked about when the first has none (the
    SAUs with `second_display_unit', base/config.ins.pas): a constant
    cell of DTTY_$INIT's. }
  dtty_second_display_unit = 2;

%if dtty_color_board or dtty_gpu %then
type
  { The mode word as the color board takes it back: whole, and its low
    byte set all ones. }
  dtty_color_mode_t = record
    case integer of
      1: (all: pinteger);                 { 0x00 }
      2: (high: char;                     { 0x00 }
          low: boolean);                  { 0x01 }
  end;

  { The color board's clear command, five words: the operation, the
    window's left and bottom limits, then its right and top limits as
    they lie in the window, one longword. }
  dtty_color_clear_t = record
    op: pinteger;                         { 0x00 }
    xs: integer;                          { 0x02 }
    ye: integer;                          { 0x04 }
    xe_ys: integer32;                     { 0x06 }
  end;

%endif
%if dtty_color_board %then
const
  { The color board's clear command (dtty_$color_clear_window). }
  dtty_color_op_clear = 16#F100;

type
  { The color graphics board's registers at COLOR_SUP (the map's I/O
    definitions) as the display TTY reaches them: the status word, its
    members 13 and 15 set while the board is busy; the mode word, read;
    the command word, written. `[device]': hardware registers. }
  dtty_color_regs_t = [device] record
    unused_00: pinteger;                  { 0x00 }
    status: set of 0..15;                 { 0x02 }
    unused_04: array[2..76] of pinteger;  { 0x04 }
    mode: pinteger;                       { 0x9A }
    unused_9c: pinteger;                  { 0x9C }
    data: pinteger;                       { 0x9E }
  end;

  { A command's words, as many as its count (dtty_$color_command's
    formal is `univ'). }
  dtty_color_words_t = array[1..1] of pinteger;

  { A window seen as dtty_$color_clear_window reads it (the layout of
    smd_$window_limits_t). }
  dtty_color_window_view_t = record
    xs: integer;                          { 0x00 }
    xe_ys: integer32;                     { 0x02 }
    ye: integer;                          { 0x06 }
  end;

var
  { COLOR_SUP (map symbol of the I/O definitions): the color board's
    register page. }
  color_sup: extern dtty_color_regs_t;

%endif
%if dtty_gpu %then
const
  { The graphics processor's commands the display TTY sends: the clear
    of a window, and the font command dtty_$load_font sends first. }
  dtty_gpu_op_clear = 16#E000;
  dtty_gpu_op_font = 16#48B0;

type
  { The graphics processor's control block at KOLOR_CTL (the map's I/O
    definitions) as the display TTY reaches it: the DN570's command
    FIFO at +0x3000 (written a word at a time, as many as the free
    count at +0x7040, low four bits, allows); the DN580's command
    registers, the argument count at +0x3002, the arguments from
    +0x3004 and the operation at +0x3640, written last; the DN580's
    status at +0x700E and the DN570's at +0x7030, member 14 set when
    the processor is done, member 15 of the first set while it is busy.
    `[device]': hardware registers. }
  dtty_gpu_regs_t = [device] record
    unused_0000: array[0..6143] of pinteger;          { 0x0000 }
    fifo: pinteger;                                   { 0x3000 }
    count: pinteger;                                  { 0x3002 }
    args: array[0..797] of pinteger;                  { 0x3004 }
    op: pinteger;                                     { 0x3640 }
    unused_3642: array[6945..14342] of pinteger;      { 0x3642 }
    status: set of 0..15;                             { 0x700E }
    unused_7010: array[14344..14359] of pinteger;     { 0x7010 }
    status_7030: set of 0..15;                        { 0x7030 }
    unused_7032: array[14361..14367] of pinteger;     { 0x7032 }
    fifo_count: pinteger;                             { 0x7040 }
  end;

  { A command's words, as dtty_$gpu_command reads them: the operation,
    the count of its arguments and the arguments, one command after
    another. }
  dtty_gpu_words_t = array[1..1] of pinteger;
  dtty_gpu_words_ptr_t = ^dtty_gpu_words_t;

  { The clear command, six words: the operation, its four arguments'
    count, and the window's left, bottom, right and top limits. }
  dtty_gpu_clear_t = record
    op: pinteger;                         { 0x00 }
    count: integer;                       { 0x02 }
    xs: integer;                          { 0x04 }
    ys: integer;                          { 0x06 }
    xe: integer;                          { 0x08 }
    ye: integer;                          { 0x0A }
  end;

  { The font command, eight words: the operation, its six arguments'
    count, and the arguments. }
  dtty_gpu_font_t = record
    op: pinteger;                         { 0x00 }
    count: integer;                       { 0x02 }
    args: array[1..6] of integer;         { 0x04 }
  end;

var
  { KOLOR_CTL (map symbol of the I/O definitions): the graphics
    processor's control block. }
  kolor_ctl: extern dtty_gpu_regs_t;

%endif
{ ---- WIRED_PROC ---- }
%if display_driver %then
%include 'dtty/get_disp_type.pas';          { dtty_$get_disp_type }
%if dtty_gpu %then
%include 'dtty/gpu_command.pas';            { dtty_$gpu_command }
%endif
%if dtty_color_board %then
%include 'dtty/color_command.pas';          { dtty_$color_command }
%endif
%if dtty_color_board or dtty_gpu %then
%include 'dtty/color_clear_window.pas';     { dtty_$color_clear_window }
%endif
%include 'dtty/clear_window.pas';           { dtty_$clear_window }
%include 'dtty/report_error.pas';           { dtty_$report_error }
%include 'dtty/load_font.pas';              { dtty_$load_font }
%include 'dtty/write_string.pas';           { DTTY_$WRITE_STRING }
%include 'dtty/tstart.pas';                 { DTTY_$TSTART       }
%include 'dtty/reload_font.pas';            { DTTY_$RELOAD_FONT  }
%endif

{ ---- OS_INIT_PROC ---- }
%include 'dtty/init.pas';                   { DTTY_$INIT         }
