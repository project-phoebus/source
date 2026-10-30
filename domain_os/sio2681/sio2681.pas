{ sio2681/sio2681.pas - the SIO_IO module, the serial controller drivers
  (the 2681 DUART's and the 6509 console controller's).

  Image addresses:
    sau2  0x00E2DEB8  SIO_IO data (WIRED_DATA, 0xC8 bytes)
    sau2  0x00E351EC  SIO_IO data (OS_INIT_DATA, 0x8 bytes)

  One compilation unit: the map's SIO_IO code segments in WIRED_PROC
  (0x69C bytes, SIO2681_$INT .. SIO2681_$XMIT, SIO6509_$RCV,
  SIO6509_$XMIT), OS_INIT_PROC (0x194 bytes, SIO2681_$INIT,
  SIO6509_$INIT) and PROCEDURE$ (0xE0 bytes, SIO2681_$INQ_LINE,
  SIO6509_$SET_LINE, SIO6509_$INQ_LINE), and its data segments in
  WIRED_DATA (0xC8 bytes) and OS_INIT_DATA (8 bytes).

  The hand-written SIO_INT data segment (0x8C bytes;
  sio2681/m68k/int_rte.s, sio6509/m68k/int1_rte.s) is another object.
  The 6509's routines (sio6509/README.md) lie in the three code
  segments after the 2681's, their fragments included here.  With
  `sio16550_lines' (base/config.ins.pas) the map's SIO_IO module is the
  16550's (sio16550/sio16550.pas) and this body is left out.

  The heading: `module sio_io, wired_proc, wired_data;'.  SIO2681_$INIT
  is headed `[section(os_init_proc, os_init_data)]' (the OS_INIT_DATA
  block is its static), SIO2681_$INQ_LINE and the 6509's PROCEDURE$
  routines `[section(procedure$, data$)]'.

  The data, WIRED_DATA, 0xC8 bytes:

    +0x00  spin_lock            4      the lock (ML_$SPIN_LOCK ...)
    +0x04  reserved_04          4      nothing (stand-in)
    +0x08  error_table          0x40   16 longwords
    +0x48  cmd_break_stop       1 (2)  16#70
    +0x4A  cmd_break_start      1 (2)  16#60
    +0x4C  default_baud         4      14 and 14

    +0x50  baud_masks           4      1 and 2, indexed by the chip's
                                       baud-rate set
    +0x54  cmd_reset_mr_ptr     1 (2)  16#10
    +0x56  cmd_reset_err_enable 1 (2)  16#45
    +0x58  cmd_reset_rx         1 (2)  16#2A
    +0x5A  cmd_reset_tx         1 (2)  16#3A

    +0x5C  cmd_disable_rx_tx    1 (2)  16#0A
    +0x5E  mr2_template         2      16#07 in its first byte
    +0x60  mr1_template         2      16#0B in its first byte
    +0x62  baud_bits            0x22   17 words
    +0x84  baud_codes           0x22   17 words of 0..15, read at their
                                       low bytes

    +0xA6  pad_a6               2      nothing (stand-in)
    +0xA8  sio6509_rcv_flags    0x20   8 longwords (sio6509/rcv.pas: 0,
                                       2, 4, 6, 1, 5, 3, 0)

  Each char variable takes a word.  OS_INIT_DATA, 8 bytes: SIO2681_$INIT's
  static int_vectors (init.pas).

  The routines, in image order within each section; sio2681_set_baud_rate
  is module-local (internal, no map symbol), every other routine global.

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/sio2681/sio2681.pas.  Check: tools/pascal_check.sh.
}
module sio_io, wired_proc, wired_data;

%include 'base/base.ins.pas';
%if not sio16550_lines %then
%include 'ml/ml.ins.pas';
%include 'ec/ec.ins.pas';
%include 'time/time.ins.pas';
%include 'sio/sio.ins.pas';
%include 'sio2681/sio2681.ins.pas';
%include 'sio6509/sio6509.ins.pas';
%include 'pchist/pchist.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  sio2681_$int;
  sio2681_$set_break;
  sio2681_$tone;
  sio2681_$set_line;
  sio2681_$xmit;
  sio6509_$rcv;
  sio6509_$xmit;
  sio2681_$init;
  sio6509_$init;
  sio2681_$inq_line;
  sio6509_$set_line;
  sio6509_$inq_line;

{ The module's own types, used by SIO2681_$SET_LINE and
  sio2681_set_baud_rate only. }
type
  { The 2681's mode register 1 as a packed record (ref 3.10.7: the first
    field at the most significant bit; 16 bits in all, MR1's byte the
    first): a frame word set from the template whole, its fields changed
    in place on the byte, the byte written to the register.  The names
    are the 2681's bits: 7 RxRTS, 6 RxINT, 5 error mode, 4..3 parity
    mode, 2 parity type, 1..0 bits per character. }
  sio2681_$mr1_t = packed record
    case integer of
      1: (c: char);
      2: (rx_rts: boolean;
          rx_int: boolean;
          err_block: boolean;
          parity_mode: 0..3;
          parity_odd: boolean;
          bits: 0..3);
  end;

  { Mode register 2 the same way (bits: 7..6 channel mode, 5 TxRTS, 4
    CTS enables the transmitter, 3..0 stop bits). }
  sio2681_$mr2_t = packed record
    case integer of
      1: (c: char);
      2: (mode: 0..3;
          tx_rts: boolean;
          cts_tx: boolean;
          stop: 0..15);
  end;

  { The clock select byte: the receive rate's code in the high nibble,
    the transmit rate's in the low (sio2681_set_baud_rate), written
    whole. }
  sio2681_$csr_t = packed record
    case integer of
      1: (c: char);
      2: (rx: 0..15;
          tx: 0..15);
  end;

{ The module's variables, in the order of the WIRED_DATA block, with the
  image's bytes (ref 3.2.2 p. 3-4: initial values of module variables). }
var
  spin_lock: integer32;                   { +0x00, 0 }
  reserved_04: integer32;                 { +0x04, 0: stand-in }
  error_table: array[0..15] of integer32 := { +0x08 }
    [16#00, 16#04, 16#01, 16#05, 16#02, 16#06, 16#03, 16#07,
     16#20, 16#24, 16#21, 16#25, 16#22, 16#26, 16#23, 16#27];
  cmd_break_stop: char := chr(16#70);     { +0x48 }
  cmd_break_start: char := chr(16#60);    { +0x4A }
  default_baud: sio2681_$rates_t :=       { +0x4C }
    [tx := 14, rx := 14];
  baud_masks: array[boolean] of pinteger := [1, 2];  { +0x50 }
  cmd_reset_mr_ptr: char := chr(16#10);   { +0x54 }
  cmd_reset_err_enable: char := chr(16#45); { +0x56 }
  cmd_reset_rx: char := chr(16#2A);       { +0x58 }
  cmd_reset_tx: char := chr(16#3A);       { +0x5A }
  cmd_disable_rx_tx: char := chr(16#0A);  { +0x5C }
  mr2_template: sio2681_$mr2_t := [c := chr(16#07)];  { +0x5E }
  mr1_template: sio2681_$mr1_t := [c := chr(16#0B)];  { +0x60 }
  baud_bits: array[0..16] of pinteger :=  { +0x62 }
    [1, 2, 3, 3, 2, 3, 3, 3, 2, 0, 3, 0, 3, 1, 3, 2, 1];
  baud_codes: array[0..16] of 0..15 :=    { +0x84 }
    [0, 0, 1, 2, 3, 4, 5, 6, 7, 0, 8, 0, 9, 10, 11, 12, 13];
  pad_a6: integer;                        { +0xA6, 0: stand-in }
  sio6509_rcv_flags: array[0..7] of integer32 :=  { +0xA8 }
    [0, 2, 4, 6, 1, 5, 3, 0];

{ ---- WIRED_PROC ---- }
%include 'sio2681/int.pas';                 { SIO2681_$INT          }
%include 'sio2681/set_break.pas';           { SIO2681_$SET_BREAK    }
%include 'sio2681/tone.pas';                { SIO2681_$TONE         }
%include 'sio2681/set_baud_rate.pas';       { sio2681_set_baud_rate }
%include 'sio2681/set_line.pas';            { SIO2681_$SET_LINE     }
%include 'sio2681/xmit.pas';                { SIO2681_$XMIT         }
%include 'sio6509/rcv.pas';                 { SIO6509_$RCV          }
%include 'sio6509/xmit.pas';                { SIO6509_$XMIT         }

{ ---- OS_INIT_PROC ---- }
%include 'sio2681/init.pas';                { SIO2681_$INIT         }
%include 'sio6509/init.pas';                { SIO6509_$INIT         }

{ ---- PROCEDURE$ ---- }
%include 'sio2681/inq_line.pas';            { SIO2681_$INQ_LINE     }
%include 'sio6509/set_line.pas';            { SIO6509_$SET_LINE     }
%include 'sio6509/inq_line.pas';            { SIO6509_$INQ_LINE     }
%endif
