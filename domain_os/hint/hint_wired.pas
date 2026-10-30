{ hint/hint_wired.pas - the HINT_WIRED module, HINT_'s wired lock.

  Image addresses:
    sau2  0x00E2C034  HINT_WIRED data (WIRED_DATA, 0x14 bytes)

  A map module of data only: HINT_$EXCLUSION_LOCK, an ml_$exclusion_t
  of 0x12 bytes, the segment's 0x14 its rounding to 4; zero in the
  image.
  The HINT_ routines reach it as another unit's variable, by address.

  The heading: `module hint_wired, , wired_data;' (no code section).

  Check: tools/pascal_check.sh.
}
module hint_wired, , wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'uid/uid.ins.pas';
%include 'hint/hint.ins.pas';

define
  hint_$exclusion_lock;                            { +0x00, zero }
