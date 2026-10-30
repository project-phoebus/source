{ NAME_$DROP - drop a pathname's leaf from its directory.

  Image addresses:
    sau2  0x00E4A2B8  NAME_$DROP

  - name_$resolve_dir_and_leaf, then DIR_$DROPU, which hands back the
    dropped object's UID.

  Status stored:
    dir_$dropu's status: the path resolved
    name_$resolve_dir_and_leaf's status: it did not
}

procedure name_$drop(in path: univ name_$long_pname_t;
                     in path_len: integer;
                     var file_uid: uid_$t;
                     out status: status_$t);
var
  dir_uid: uid_$t;
  filename_len: integer;
  filename_idx: pinteger;                 { also held }
begin
  if name_$resolve_dir_and_leaf(path, path_len, filename_idx, filename_len,
                                dir_uid, status) then
    dir_$dropu(dir_uid, path[filename_idx], filename_len, file_uid, status);
end;
