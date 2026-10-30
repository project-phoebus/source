{ ring/ringlog_.pas - the RINGLOG_ module: the ring's packet log.

  Image addresses:
    sau2  0x00E2C32C  RINGLOG_ data (WIRED_DATA, 0x3C bytes)

  One compilation unit in two code sections and one data section: the
  map's RINGLOG_ code segments in WIRED_PROC (0x1F8 bytes,
  RINGLOG_$LOGIT) and in PROCEDURE$ (0x168 bytes, RINGLOG_$CNTL), and
  its RINGLOG_ data segment in WIRED_DATA (0x3C bytes).  The log buffer
  is the overlay section RINGLOG_$DATA (ring/ringlog.ins.pas).

  The heading: the block's objects are module variables shared by both
  routines, five of them map symbols `define'd here, so `module
  ringlog_, wired_proc, wired_data;' (ring/ring.pas's shape).
  RINGLOG_$CNTL, in PROCEDURE$, is headed `[section(procedure$, data$)]'
  (kbd/kbd.pas) and reaches the block by its address.

  The data, 0x3C bytes:

    +0x00  ringlog_$wired_pages     0x28  zero: MST_$WIRE_AREA's page
                                          list (RINGLOG_$CNTL), from 1
    +0x28  ringlog_$spinlock        4     zero: ML_$SPIN_LOCK's lock
    +0x2C  RINGLOG_$ID              4     zero
    +0x30  ringlog_$wire_count      2     zero

    +0x32  RINGLOG_$MBX_SOCK        1     true
    +0x34  RINGLOG_$WHO_SOCK        1     true
    +0x36  RINGLOG_$NIL_SOCK        1     true
    +0x38  RING_$LOGGING_NOW        1     false
    +0x3A  ringlog_$first_entry     1     true: RINGLOG_$LOGIT's
    (each boolean at an even offset, the block rounded to 4)

  The routines: RINGLOG_$LOGIT (WIRED_PROC; ring/logit.pas);
  RINGLOG_$CNTL with its nested ringlog_$stop_logging (PROCEDURE$;
  ring/cntl.pas).

  Build: dpc -I domain_os domain_os/ring/ringlog_.pas.  Check:
  tools/pascal_check.sh.
}
module ringlog_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ml/ml.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'mst/mst.ins.pas';
%include 'wp/wp.ins.pas';
%include 'ring/ringlog.ins.pas';

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above); then the routines
  in map order. }
var
  ringlog_$wired_pages: array[1..10] of integer32;     { +0x00, zero }
  ringlog_$spinlock: integer32;                        { +0x28, zero }

define
  ringlog_$id;                                         { +0x2C, zero }

var
  ringlog_$wire_count: integer;                        { +0x30, zero }

define
  ringlog_$mbx_sock := true;                           { +0x32 }
  ringlog_$who_sock := true;                           { +0x34 }
  ringlog_$nil_sock := true;                           { +0x36 }
  ring_$logging_now;                                   { +0x38, false }

var
  ringlog_$first_entry: boolean := true;               { +0x3A }

define
  ringlog_$logit;
  ringlog_$cntl;

{ ---- WIRED_PROC ---- }
%include 'ring/logit.pas';                  { RINGLOG_$LOGIT }

{ ---- PROCEDURE$ ---- }
%include 'ring/cntl.pas';                   { ringlog_$stop_logging
                                              (nested), RINGLOG_$CNTL }
