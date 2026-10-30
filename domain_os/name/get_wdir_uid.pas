{ NAME_$GET_WDIR_UID - hand back the working directory's UID.

  Image addresses:
    sau2  0x00E58960  NAME_$GET_WDIR_UID

  - name_$wdir_uid[proc1_$as_id].

  Status stored: none.
}

procedure name_$get_wdir_uid(out wdir_uid: uid_$t);
begin
  wdir_uid := name_$wdir_uid[proc1_$as_id];
end;
