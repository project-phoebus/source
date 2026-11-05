{ MST_$GET_UID - the object mapped at an address of the current address
  space.

  Image addresses:
    sau2  0x00E43FD8  MST_$GET_UID
    sau4  0x0F84C282  MST_$GET_UID
    sau6  0x7804B5EA  MST_$GET_UID
    sau7  0x3C4543A4  MST_$GET_UID
    sau8  0x03C4C40E  MST_$GET_UID
    sau9  0x3C44B5A4  MST_$GET_UID

  - MST_$GET_VA_INFO for the current address space; the protection and
    the flags are dropped.

  Status stored:
    mst_$get_va_info's status: in either case
}

procedure mst_$get_uid(in va: integer32; out uid: uid_$t;
                       out va_info: integer32; out status: status_$t);
var
  prot: pinteger;
  modified: boolean;
  active: boolean;
  unused_8: integer;                      { stand-in }
begin
  mst_$get_va_info(proc1_$as_id, va, uid, va_info, prot,
                   active, modified, status);
end;
