{ NAME_$CR_FILE - create a file and enter it under a pathname.

  Image addresses:
    sau2  0x00E4A316  NAME_$CR_FILE

  - The file is created in the path's directory, given the directory's
    initial file ACL and entered under the leaf; a failed copy or entry
    deletes it again and the result is UID_$NIL.
  - Only FILE_$CREATE's status code word is tested.

  Status stored:
    dir_$addu's status: the file was created
    the failed step's status: the resolve, FILE_$CREATE or ACL_$COPY
}

procedure name_$cr_file(in path: univ name_$long_pname_t;
                        in path_len: integer;
                        out file_ret: uid_$t;
                        out status: status_$t);
var
  dir_uid: uid_$t;
  local_status: status_$t;
  filename_len: integer;
  filename_idx: pinteger;                 { also held }
begin
  if name_$resolve_dir_and_leaf(path, path_len, filename_idx, filename_len,
                                dir_uid, status) then begin
    file_$create(dir_uid, file_ret, status);
    if status.code = 0 then begin
      acl_$copy(dir_uid, file_ret, acl_$file_acl, acl_$filein_acl, status);
      if status.all = status_$ok then begin
        dir_$addu(dir_uid, path[filename_idx], filename_len, file_ret,
                  status);
        if status.all = status_$ok then
          return;
      end;
      discard(file_$delete(file_ret, local_status));
      file_ret := uid_$nil;
    end;
  end;
end;
