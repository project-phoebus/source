{ dtty/dtty.pas - the DTTY module, the display TTY.

  Image addresses:
    sau2  0x00E2E00C  DTTY data (WIRED_DATA, 0xC bytes)
    sau3  0x00E2CB98  DTTY data (WIRED_DATA, 4 bytes)

  One compilation unit, in two code sections and one data section: the
  map's DTTY code segments in WIRED_PROC (0x1C8 bytes: four module-local
  routines, DTTY_$WRITE_STRING, DTTY_$TSTART, DTTY_$RELOAD_FONT) and in
  OS_INIT_PROC (0x15C bytes: DTTY_$INIT and its cells), and its DTTY
  data segment in WIRED_DATA (0xC bytes; DTTY_$CTRL, DTTY_$USE_DTTY).

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

{ ---- WIRED_PROC ---- }
%if display_driver %then
%include 'dtty/get_disp_type.pas';          { dtty_$get_disp_type }
%include 'dtty/clear_window.pas';           { dtty_$clear_window }
%include 'dtty/report_error.pas';           { dtty_$report_error }
%include 'dtty/load_font.pas';              { dtty_$load_font }
%include 'dtty/write_string.pas';           { DTTY_$WRITE_STRING }
%include 'dtty/tstart.pas';                 { DTTY_$TSTART       }
%include 'dtty/reload_font.pas';            { DTTY_$RELOAD_FONT  }
%endif

{ ---- OS_INIT_PROC ---- }
%include 'dtty/init.pas';                   { DTTY_$INIT         }
