{ MST_$GET_UID_ASID - the object mapped at an address of a given address
  space.

  Image addresses:
    sau2  0x00E44010  MST_$GET_UID_ASID
    sau4  0x0F84C2BA  MST_$GET_UID_ASID
    sau8  0x03C4C446  MST_$GET_UID_ASID
    sau9  0x3C44B5DC  MST_$GET_UID_ASID

  - MST_$GET_VA_INFO for the address space; the protection and the flags
    are dropped.

  Status stored:
    mst_$get_va_info's status: in either case
}

procedure mst_$get_uid_asid(in asid: integer; in va: integer32;
                            out uid: uid_$t; out va_info: integer32;
                            out status: status_$t);
var
  prot: pinteger;
  asid_copy: integer;
  modified: boolean;
  active: boolean;
begin
  asid_copy := asid;
  mst_$get_va_info(asid_copy, va, uid, va_info, prot,
                   active, modified, status);
end;
