{ uid/uid.pas - the UID_ module, the unique identifier generator.

  Image addresses:
    sau2  0x00E2C008  UID_ data (WIRED_DATA, 0xC bytes)

  One compilation unit, `module uid_, wired_proc, wired_data;': the
  map's UID_ code segments in WIRED_PROC (UID_$GEN) and OS_INIT_PROC
  (UID_$INIT, headed `[section(os_init_proc, os_init_data)]'), and its
  data segment in WIRED_DATA (12 bytes).  UID_$HASH (hand-written) and
  UID_LIST (the well-known UIDs, data) are other segments.

  The data, all zero in the image, no map symbol inside:
    +0x00  uid_$generator_state  8 bytes
    +0x08  uid_$generator_lock   4 bytes, ML_$SPIN_LOCK's lock

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/uid/uid.pas.  Check: tools/pascal_check.sh.
}
module uid_, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'node/node.ins.pas';
%include 'uid/uid.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  uid_$gen;
  uid_$init;

{ The module's variables, in the order of the block, zero in the image
  (uninitialized, like the blocks of LOG_ and of BITPAD). }
var
  uid_$generator_state: uid_$gen_state_t; { +0x00 }
  uid_$generator_lock: integer32;         { +0x08 }

{ ---- WIRED_PROC ---- }
%include 'uid/gen.pas';                     { UID_$GEN  }

{ ---- OS_INIT_PROC ---- }
%include 'uid/init.pas';                    { UID_$INIT }
