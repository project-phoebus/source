{ name_$resolve_dir_and_leaf - resolve a pathname's directory, find its
  leaf.

  Image addresses:
    sau2  0x00E4A1E2  name_$resolve_dir_and_leaf

  - name_$split_path, then name_$resolve_internal on the directory part;
    the result is whether the status is ok.

  Status stored:
    name_$resolve_internal's status: other than "directory not found in
      pathname"
    name_$bad_pathname: the path has no leaf
    name_$not_found: "directory not found in pathname"
}

function name_$resolve_dir_and_leaf(in path: univ name_$long_pname_t;
                                    path_len: pinteger;
                                    out filename_idx: pinteger;
                                    out filename_len: integer;
                                    out dir_uid: uid_$t;
                                    out status: status_$t): boolean;
  internal;
var
  parent_uid: uid_$t;
  dirname_len: pinteger;
begin
  name_$resolve_dir_and_leaf := false;

  name_$split_path(path, path_len, dirname_len, filename_idx, filename_len);
  if filename_len = 0 then
    status.all := name_$bad_pathname
  else begin
    name_$resolve_internal(path, dirname_len, parent_uid, dir_uid, status);
    if status.all = status_$naming_directory_not_found_in_pathname then
      status.all := name_$not_found;
    if status.all = status_$ok then
      name_$resolve_dir_and_leaf := true;
  end;
end;
