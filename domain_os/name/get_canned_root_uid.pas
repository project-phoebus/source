{ NAME_$GET_CANNED_ROOT_UID - hand back the canned root UID.

  Image addresses:
    sau2  0x00E58A20  NAME_$GET_CANNED_ROOT_UID

  - NAME_$CANNED_ROOT_UID, UID_LIST's object.

  Status stored: none. }

procedure name_$get_canned_root_uid(out canned_root_uid: uid_$t);
begin
  canned_root_uid := name_$canned_root_uid;
end;
