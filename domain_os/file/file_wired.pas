{ file/file_wired.pas - the FILE_WIRED module, FILE_'s per-UID lock
  eventcount.

  Image addresses:
    sau2  0x00E2C028  FILE_WIRED data (WIRED_DATA, 0xC bytes)

  A map module of data only.  Its one object, FILE_$UID_LOCK_EC (ec/
  ec.ins.pas ec_$eventcount_t, the segment's whole size), is the
  eventcount FILE_'s per-UID bucket locks wait on, zero in the image,
  named by its absolute address: the global this unit defines
  (acl/acl_wired.pas's shape).  Its extern declaration is in
  file/file.pas.

  The heading: `module file_wired, , wired_data;' (ref 2.2.1 p. 2-10's
  `name, , data_section' form).

  Check: tools/pascal_check.sh.
}
module file_wired, , wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';

var
  file_$uid_lock_ec: extern ec_$eventcount_t;

define
  file_$uid_lock_ec;                               { +0x00, zero }
