{ mt/mt_sio.pas - the MT_$SIO module, the magnetic tape driver's
  wired transfer code.

  On the SAUs with the driver (`mt_driver', base/config.ins.pas) one
  compilation unit, one code segment, no data: on the SAU5 the map's
  MT_$SIO code segment in .TEXT (0x2C0 bytes: MT_$SIO, with
  MT_$PROC_START at its first byte, and MT_$GET_IOVA), which
  MT_$ACQUIRE wires with the MT page (from MT_$PROC_START to
  MT_$PROC_END, the map's MT_END_ADDR marker after this segment).

  Elsewhere the module is empty: its whole body is conditional.

  The code is in the default section and there is no data, so the
  heading names no section.  The routines live in one fragment file
  each (mt/<name>.pas), in image order.

  Check: tools/pascal_check.sh.
}
module mt_$sio;

%include 'base/base.ins.pas';
%if mt_driver %then
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'io/io.ins.pas';
%include 'pbu/pbu.ins.pas';
%include 'mt/mt.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  mt_$sio;
  mt_$get_iova;

{ ---- .TEXT ---- }
%include 'mt/sio.pas';                     { MT_$SIO }
%include 'mt/get_iova.pas';                { MT_$GET_IOVA }
%endif
