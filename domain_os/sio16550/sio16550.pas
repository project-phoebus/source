{ sio16550/sio16550.pas - the SIO_IO module of the SAUs with
  `sio16550_lines', the 16550 UART driver (the serial lines).

  Image addresses:
    sau9  0x3C43337C  SIO_IO data (WIRED_DATA, 0x98 bytes)
    sau9  0x3C43BE3C  SIO_IO data (OS_INIT_DATA, 0x28 bytes)

  One compilation unit: the map's SIO_IO code segments in WIRED_PROC
  (0x350 bytes, SIO16550_$XMIT, _$INT, _$SET_LINE with its nested
  set_baud, _$SET_BREAK), OS_INIT_PROC (0xD8 bytes, SIO16550_$INIT) and
  PROCEDURE$ (0x68 bytes, SIO16550_$INQ_LINE), and its data segments in
  WIRED_DATA (0x98 bytes) and OS_INIT_DATA (0x28 bytes).  On the other
  SAUs the map's SIO_IO module is the 2681's and the 6509's
  (sio2681/sio2681.pas); the whole body here is `sio16550_lines''s.

  The heading: `module sio_io, wired_proc, wired_data;'.  SIO16550_$INIT
  is headed `[section(os_init_proc, os_init_data)]' (the OS_INIT_DATA
  block is its static), SIO16550_$INQ_LINE `[section(procedure$,
  data$)]'.

  The data, WIRED_DATA, 0x98 bytes:

    +0x00  chans          0x40  the four ports' channel records
    +0x40  baud_rates     0x22  17 words, the rates in bits per second
    +0x62  unused_62      2     zero, nothing reads it
    +0x64  rate_ok        4     the rates the divisor serves, a set
    +0x68  spin_lock      4     the driver's lock
    +0x6C  unused_6c      4     zero, nothing reads it
    +0x70  error_table    0x20  8 longwords, SIO_$I_RCV's error flags
                                by the line status's error bits
    +0x90  wls_codes      8     4 words of 0..3, read at their low bytes

  OS_INIT_DATA, 0x28 bytes: SIO16550_$INIT's static vtable (init.pas).

  The routines, in image order within each section; every one a map
  global but set_line's nested set_baud.
}
module sio_io, wired_proc, wired_data;

%include 'base/base.ins.pas';
%if sio16550_lines %then
%include 'ml/ml.ins.pas';
%include 'ec/ec.ins.pas';
%include 'time/time.ins.pas';
%include 'io/io.ins.pas';
%include 'sysbus/sysbus.ins.pas';
%include 'sio/sio.ins.pas';
%include 'sio16550/sio16550.ins.pas';
%include 'pchist/pchist.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  sio16550_$xmit;
  sio16550_$int;
  sio16550_$set_line;
  sio16550_$set_break;
  sio16550_$init;
  sio16550_$inq_line;

{ The module's variables, in the order of the WIRED_DATA block, with the
  image's bytes (ref 3.2.2 p. 3-4: initial values of module variables). }
var
  chans: array[0..sio16550_$max_port] of sio16550_$chan_t;  { +0x00, 0 }
  baud_rates: array[0..16] of pinteger := { +0x40 }
    [50, 75, 110, 134, 150, 300, 600, 1200, 1800, 2000, 2400, 3600,
     4800, 7200, 9600, 19200, 38400];
  unused_62: integer;                     { +0x62, 0: stand-in }
  rate_ok: sio_$flags_t :=                { +0x64: 16#0001FEFF }
    [0..7, 9..16];
  spin_lock: integer32;                   { +0x68, 0 }
  unused_6c: integer32;                   { +0x6C, 0: stand-in }
  error_table: array[0..7] of integer32 :=  { +0x70 }
    [0, 4, 1, 5, 2, 6, 3, 7];
  wls_codes: array[sio_$word_size_t] of 0..3 :=  { +0x90 }
    [0, 1, 2, 3];

{ ---- WIRED_PROC ---- }
%include 'sio16550/xmit.pas';               { SIO16550_$XMIT        }
%include 'sio16550/int.pas';                { SIO16550_$INT         }
%include 'sio16550/set_line.pas';           { SIO16550_$SET_LINE,
                                              nested set_baud       }
%include 'sio16550/set_break.pas';          { SIO16550_$SET_BREAK   }

{ ---- OS_INIT_PROC ---- }
%include 'sio16550/init.pas';               { SIO16550_$INIT        }

{ ---- PROCEDURE$ ---- }
%include 'sio16550/inq_line.pas';           { SIO16550_$INQ_LINE    }
%endif
