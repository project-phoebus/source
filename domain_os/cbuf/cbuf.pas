{ cbuf/cbuf.pas - the CBUF module, the circular buffer manager.

  Image addresses:
    sau3  0x00E844D4  CBUF data (.DATA, 4 bytes)
    sau4  0x0F893B1C  CBUF data (.DATA, 4 bytes)

  One compilation unit, one code segment and one data segment: the
  map's CBUF code segment (.TEXT, 0x2E8 bytes: CBUF_$INIT_CB ..
  CBUF_$RELEASE, in the order of the `define' list) and its data segment
  in .DATA (4 bytes, the spin lock below).  The line printer driver
  (lpr/) is the user: its control block is LPR_$BCB, and CBUF's code
  lies inside LPR's wired range (LPR_$PROC_START .. LPR_$PROC_END).

  Present on the SAUs with the part circular_buffers
  (base/config.ins.pas): the SR10.2 maps of the SAU3 and SAU4 have the
  two segments, the others none.  Elsewhere the module is empty: its
  whole body is conditional.

  The heading names no section.  The data block, zero:

    +0x0  cbuf_lock  the spin lock CBUF_$ALLOCATE takes

  The routines live in one fragment file each (cbuf/<name>.pas), in
  image order.

  Check: tools/pascal_check.sh.
}
module cbuf;

%include 'base/base.ins.pas';
%if circular_buffers %then
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'fim/fim.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'cbuf/cbuf.ins.pas';

var
  cbuf_lock: integer32;                         { +0x0 }

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  cbuf_$init_cb;
  cbuf_$allocate;
  cbuf_$make_visible;
  cbuf_$read_next;
  cbuf_$release;

{ ---- .TEXT ---- }
%include 'cbuf/init_cb.pas';                { CBUF_$INIT_CB }
%include 'cbuf/allocate.pas';               { CBUF_$ALLOCATE }
%include 'cbuf/make_visible.pas';           { CBUF_$MAKE_VISIBLE }
%include 'cbuf/read_next.pas';              { CBUF_$READ_NEXT }
%include 'cbuf/release.pas';                { CBUF_$RELEASE }
%endif
