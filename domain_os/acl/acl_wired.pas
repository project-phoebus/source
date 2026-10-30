{ acl/acl_wired.pas - the ACL_WIRED module, ACL_'s exclusion lock.

  Image addresses:
    sau2  0x00E2C014  ACL_WIRED data (WIRED_DATA, 0x14 bytes)

  A map module of data only, `module acl_wired, , wired_data;': the
  ACL_WIRED segment in WIRED_DATA (20 bytes), its one object the
  exclusion lock ACL_$EXCLUSION_LOCK, zero in the image, and 2 bytes of
  rounding.

  ACL_'s routines name the lock by its absolute address, so it is this
  unit's global; its extern declaration is in acl/acl.pas.

  Check: tools/pascal_check.sh.
}
module acl_wired, , wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';

var
  acl_$exclusion_lock: extern ml_$exclusion_t;

define
  acl_$exclusion_lock;                             { +0x00, zero }
