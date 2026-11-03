{ term/os_term.pas - the OS_TERM module, the terminal manager's entry
  points.

  Image addresses:
    sau2  0x00E2C98C  OS_TERM data (WIRED_DATA, 0x64 bytes)
    sau2  0x00E82428  OS_TERM data (.DATA, 4 bytes)
    sau3  0x00E2B6D8  OS_TERM data (WIRED_DATA, 0x64 bytes)
    sau3  0x00E83B3C  OS_TERM data (.DATA, 4 bytes)
    sau4  0x0F82F548  OS_TERM data (WIRED_DATA, 0x64 bytes)
    sau4  0x0F890B9C  OS_TERM data (.DATA, 4 bytes)

  One compilation unit, `module os_term;': the map's OS_TERM code
  segments in WIRED_PROC (TERM_$GET_REAL_LINE, KBD_$GET_DESC,
  TERM_$SEND_KBD_STRING), .TEXT (TTY_$I_GET_DESC .. TERM_$INQUIRE) and
  PROCEDURE$ (TERM_$GET_EC, TERM_$HELP_CALLBACK), each headed with its
  sections; one unit because term_$status_convert is called across
  them.

  The data: WIRED_DATA (100 bytes) is term_$status_convert's three
  tables; .DATA (4 bytes) TERM_$PCHIST_FLAG, zero, which no code
  addresses.

  The routines live in one fragment file each, included below in image
  order with KBD_$GET_DESC, TTY_$I_GET_DESC and SIO_$I_GET_DESC.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/term/os_term.pas.  Check: tools/pascal_check.sh.
}
module os_term;

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

{ The global variable this module defines (ref 7.3.4, Method 2): .DATA,
  +0x0. }
define
  term_$pchist_flag;

{ The global routines, in map order; SIO_$I_GET_DESC's heading is in
  sio/sio.ins.pas. }
define
  term_$get_real_line;
  kbd_$get_desc;
  term_$send_kbd_string;
  tty_$i_get_desc;
  sio_$i_get_desc;
  term_$read;
  term_$read_cond;
  term_$write;
  term_$control;
  term_$inquire;
  term_$get_ec;
  term_$help_callback;

{ ---- WIRED_PROC ---- }
%include 'term/get_real_line.pas';          { TERM_$GET_REAL_LINE }
%include 'kbd/get_desc.pas';                { KBD_$GET_DESC }
%include 'term/status_convert.pas';         { term_$status_convert }
%include 'term/send_kbd_string.pas';        { TERM_$SEND_KBD_STRING }

{ ---- .TEXT ---- }
%include 'tty/i_get_desc.pas';              { TTY_$I_GET_DESC }
%include 'sio/i_get_desc.pas';              { SIO_$I_GET_DESC }
%include 'term/read.pas';                   { TERM_$READ }
%include 'term/read_cond.pas';              { TERM_$READ_COND }
%include 'term/write.pas';                  { TERM_$WRITE }
%include 'term/control.pas';                { TERM_$CONTROL }
%include 'term/inquire.pas';                { TERM_$INQUIRE }

{ ---- PROCEDURE$ ---- }
%include 'term/get_ec.pas';                 { TERM_$GET_EC }
%include 'term/help_callback.pas';          { TERM_$HELP_CALLBACK }
