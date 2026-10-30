{ color7/color7.pas - the COLOR7 module, a display driver.

  Configured out on the SAU2.  One compilation unit, one code segment, no
  data: the map's COLOR7 segment (4 bytes) in section COLOR7_WIRED_PRO,
  holding COLOR7_$WORTHLESS and the module-end filler.  The module is the
  map segment's name, COLOR7; the section names are the map's, cut at 16
  characters (`COLOR7_WIRED_PRO', `COLOR7_$WIRED_DA').

  Why a routine named "worthless": where the display is configured out,
  the driver's section still exists and holds this one empty procedure.
  The module is conditional on the driver (`color7_driver',
  base/config.ins.pas); the driver's arm is not written (TODO(sau)
  below).

  The module has no data, so the heading names no section and the
  routine is headed `[section(color7_wired_proc, color7_$wired_data)]'.

  Check: tools/pascal_check.sh.
}
module color7;

%include 'base/base.ins.pas';
%include 'color7/color7.ins.pas';

{ TODO(sau) COLOR7's wired driver code on the SAUs with this display

  The `%then' arm is the driver's wired routines and their `define'
  list (the other SAUs' maps name their segments), to be translated from
  an image that has them. }

%if color7_driver %then
%else
{ The global routines this module defines (ref 7.3.4, Method 2). }
define
  color7_$worthless;

{ ---- COLOR7_WIRED_PROC ---- }
%include 'color7/worthless.pas';               { COLOR7_$WORTHLESS }
%endif
