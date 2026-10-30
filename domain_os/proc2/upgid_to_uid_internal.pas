{ proc2_$upgid_to_uid_internal - a process group's synthetic UID.

  Image addresses:
    sau2  0x00E4232A  proc2_$upgid_to_uid_internal (module-local)

  - UID_$NIL with the UNIX group id in the word at +2; the high byte
    stays 0, which tells it from a process's UID.

  Status stored: none.
}

function proc2_$upgid_to_uid_internal(upgid: integer): uid_$t;
var
  u: proc2_pgroup_uid_view_t;
begin
  u.uid := uid_$nil;
  u.upgid := upgid;
  proc2_$upgid_to_uid_internal := u.uid;
end;
