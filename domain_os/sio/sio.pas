{ sio/sio.pas - the SIO module, the serial lines' generic layer.

  Image addresses:
    sau2  0x00E2DDDC  SIO data (WIRED_DATA, 0x8 bytes)
    sau2  0x00E82458  SIO data (.DATA, 0x4 bytes)
    sau4  0x0F830F48  SIO data (WIRED_DATA, 0x8 bytes)
    sau4  0x0F890BCC  SIO data (.DATA, 0x4 bytes)
    sau6  0x780329F8  SIO data (WIRED_DATA, 0x8 bytes)
    sau6  0x7809CB30  SIO data (.DATA, 0x4 bytes)
    sau7  0x3C4357C0  SIO data (WIRED_DATA, 0x8 bytes)
    sau7  0x3C4AB74C  SIO data (.DATA, 0x4 bytes)

  One compilation unit, `module sio;': the map's SIO code segments in
  WIRED_PROC (SIO_$I_RCV .. SIO_$I_INHIBIT_XMIT, headed
  `[section(wired_proc, wired_data)]') and in .TEXT (SIO_$I_ERR ..
  SIO_$K_INQ_PARAM), and its data segments in WIRED_DATA (8 bytes) and
  .DATA (4 bytes).

  SIO_$I_GET_DESC, SIO_$INIT and the sio_$init_* routines are fragments
  of the OS_TERM and OS_TERM_INIT modules (term/os_term.pas,
  term/os_term_init.pas), in whose segments they lie.

  The data, all zero in the image:
    WIRED_DATA +0x0  SIO_$I_TSTART's static zero_interval, a 6-byte
                     clock, and 2 bytes of rounding
    .DATA      +0x0  sio_$spin_lock, the module's variable

  The routines live in one fragment file each (sio/<name>.pas),
  included below in image order; SIO_DELAY_RESTART sits apart from
  SIO_$I_TSTART and has its own.

  Build: dpc -I domain_os domain_os/sio/sio.pas.  Check:
  tools/pascal_check.sh.
}
module sio;

%include 'base/base.ins.pas';
%include 'ml/ml.ins.pas';
%include 'ec/ec.ins.pas';
%include 'time/time.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'fim/fim.ins.pas';
%include 'sio/sio.ins.pas';

{ The module's variable (ref 7.2.2): .DATA +0x0, zero. }
var
  sio_$spin_lock: integer32;

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  sio_$i_rcv;
  sio_delay_restart;
  sio_$i_xmit_done;
  sio_$i_cts_change;
  sio_$i_dcd_change;
  sio_$i_tstart;
  sio_$i_inhibit_rcv;
  sio_$i_inhibit_xmit;
  sio_$i_err;
  sio_$i_init;
  sio_$k_timed_break;
  sio_$k_signal_wait;
  sio_$k_set_param;
  sio_$k_inq_param;

{ ---- WIRED_PROC ---- }
%include 'sio/i_rcv.pas';                   { SIO_$I_RCV }
%include 'sio/delay_restart.pas';           { SIO_DELAY_RESTART }
%include 'sio/i_xmit_done.pas';             { SIO_$I_XMIT_DONE }
%include 'sio/i_cts_change.pas';            { SIO_$I_CTS_CHANGE }
%include 'sio/i_dcd_change.pas';            { SIO_$I_DCD_CHANGE }
%include 'sio/i_tstart.pas';                { SIO_$I_TSTART }
%include 'sio/i_inhibit_rcv.pas';           { SIO_$I_INHIBIT_RCV }
%include 'sio/i_inhibit_xmit.pas';          { SIO_$I_INHIBIT_XMIT }

{ ---- .TEXT ---- }
%include 'sio/i_err.pas';                   { SIO_$I_ERR }
%include 'sio/i_init.pas';                  { SIO_$I_INIT }
%include 'sio/set_break.pas';               { sio_$set_break }
%include 'sio/k_timed_break.pas';           { SIO_$K_TIMED_BREAK }
%include 'sio/k_signal_wait.pas';           { SIO_$K_SIGNAL_WAIT }
%include 'sio/k_set_param.pas';             { SIO_$K_SET_PARAM }
%include 'sio/k_inq_param.pas';             { SIO_$K_INQ_PARAM }
