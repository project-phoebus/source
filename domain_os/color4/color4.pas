{ color4/color4.pas - the COLOR4 module, a display driver.

  Configured out on the SAU2: the map's COLOR4 code segment (4 bytes) in
  COLOR4_WIRED_PROC (the map's `COLOR4_WIRED_PRO', cut at 16 characters)
  holds COLOR4_$WORTHLESS alone.  No data.

  The source is read as conditional on `color4_driver'
  (base/config.ins.pas): the SAU7's and SAU8's COLOR4 segments hold the
  driver, with no COLOR4_$WORTHLESS; that arm is not written (TODO(sau)
  below).  The SAU9 has the SAU2's form.

  The routine is headed `[section(color4_wired_proc,
  color4_$wired_data)]'.

  Check: tools/pascal_check.sh.
}
module color4;

%include 'base/base.ins.pas';
%include 'color4/color4.ins.pas';

{ TODO(sau) COLOR4's wired driver code on the SAUs with this display

  The `%then' arm is the driver's wired routines and their `define'
  list (the other SAUs' maps name their segments), to be translated from
  an image that has them. }

%if color4_driver %then
%else
{ The global routines this module defines (ref 7.3.4, Method 2). }
define
  color4_$worthless;

{ ---- COLOR4_WIRED_PROC ---- }
%include 'color4/worthless.pas';               { COLOR4_$WORTHLESS }
%endif
