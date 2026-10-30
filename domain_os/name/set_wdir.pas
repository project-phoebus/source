{ NAME_$SET_WDIR - set the working directory from a pathname.

  Image addresses:
    sau2  0x00E4A3D0  NAME_$SET_WDIR

  - NAME_$RESOLVE, then NAME_$SET_WDIRUS with the result.

  Status stored:
    name_$set_wdirus' status: the path resolved
    name_$resolve's status: it did not
}

procedure name_$set_wdir(in path: univ name_$long_pname_t;
                         in path_len: integer;
                         out status: status_$t);
var
  uid: uid_$t;
begin
  name_$resolve(path, path_len, uid, status);
  if status.all = status_$ok then
    name_$set_wdirus(uid, status);
end;
