{ vfmt/vfmt.pas - the VFMT module, the kernel's formatted text output.

  One compilation unit, `module vfmt;': the map's VFMT code segment in
  .TEXT (VFMT_$MAIN, VFMT_$WRITE and their helpers) and no data.  The
  neighboring VFMT_ segments are hand assembly: the VFMT_$FORMATN and
  VFMT_$WRITEN thunks and their descriptors (vfmt/README.md).

  The routines, in image order (vfmt/format_number.pas, vfmt/main.pas,
  vfmt/write.pas):
  vfmt_format_number (module-local), VFMT_$MAIN with its four nested
  routines, VFMT_$WRITE.  Every call inside the unit is backward.

  Build: dpc -I domain_os domain_os/vfmt/vfmt.pas.  Check:
  tools/pascal_check.sh.
}
module vfmt;

%include 'base/base.ins.pas';
%include 'suma/suma.ins.pas';
%include 'term/term.ins.pas';
%include 'vfmt/vfmt.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  vfmt_$main;
  vfmt_$write;

{ The module's own types, used by vfmt_format_number and VFMT_$MAIN's
  nested routines only (vfmt/main.pas gives the evidence). }
type
  { The modifier string, 1-based in VFMT_$MAIN and 0-based in
    vfmt_format_number (its index from 0), the same ten bytes. }
  vfmt_$spec_t = array[1..10] of char;
  vfmt_$spec0_t = array[0..9] of char;

  { What an argument of a number specifier points at: a word or a
    longword, read at its first byte, signed or not. }
  vfmt_$value_t = record
    case integer of
      1: (w: integer);                    { 0x00 }
      2: (uw: pinteger);                  { 0x00 }
      3: (l: integer32);                  { 0x00 }
  end;

  { The output of vfmt_format_number, 0-based (its index from 0). }
  vfmt_$out0_t = array[0..199] of char;

  { What a string specifier's arguments point at: the characters
    (1-based), or the length, a word whose value counts when it is
    positive and otherwise the low word of a longword. }
  vfmt_$view_t = record
    case integer of
      1: (chars: array[1..32767] of char); { 0x00 }
      2: (w: integer;                     { 0x00 }
          lo: integer);                   { 0x02 }
  end;
  vfmt_$view_ptr_t = ^vfmt_$view_t;

{ ---- .TEXT ---- }
%include 'vfmt/format_number.pas';          { vfmt_format_number }
%include 'vfmt/main.pas';                   { VFMT_$MAIN and its nested
                                              routines }
%include 'vfmt/write.pas';                  { VFMT_$WRITE }
