{ NAME_$GET_NDIR_UID - hand back the naming directory's UID.

  Image addresses:
    sau2  0x00E5898E  NAME_$GET_NDIR_UID

  - name_$ndir_uid[proc1_$as_id].

  Status stored: none. }

procedure name_$get_ndir_uid(out ndir_uid: uid_$t);
begin
  ndir_uid := name_$ndir_uid[proc1_$as_id];
end;
