{ color5/color5.pas - the COLOR5 module, a display driver.

  Configured out on the SAU2.  One compilation unit, one code segment, no
  data: the map's COLOR5 code segment (section COLOR5_WIRED_PROC, 4
  bytes) holds COLOR5_$WORTHLESS and the module-end filler.  The module
  is the map segment's name, COLOR5; the section names are the map's,
  cut at 16 characters (`COLOR5_WIRED_PRO', `COLOR5_$WIRED_DA').

  COLOR5_$START_WIRED_PROC and COLOR5_$END_WIRED_PROC, the bounds of the
  driver's wired code, are layout marks, not objects of this module.

  Why a routine named "worthless": where the display is configured out,
  the driver's section still exists and holds this one empty procedure.
  The module is conditional on the driver (`color5_driver',
  base/config.ins.pas); the driver's arm is not written (TODO(sau)
  below).

  The module has no data, so the heading names no section and the
  routine is headed `[section(color5_wired_proc, color5_$wired_data)]'.

  Check: tools/pascal_check.sh.
}
module color5;

%include 'base/base.ins.pas';
%include 'color5/color5.ins.pas';

{ TODO(sau) COLOR5's wired driver code on the SAUs with this display

  The `%then' arm is the driver's wired routines and their `define'
  list (the other SAUs' maps name their segments), to be translated from
  an image that has them. }

%if color5_driver %then
%else
{ The global routines this module defines (ref 7.3.4, Method 2). }
define
  color5_$worthless;

{ ---- COLOR5_WIRED_PROC ---- }
%include 'color5/worthless.pas';               { COLOR5_$WORTHLESS }
%endif
