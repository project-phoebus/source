{ ACL_$ADD_PROJ - add a project to the current process's project list.

  Image addresses:
    sau2  0x00E47EAC  ACL_$ADD_PROJ

  - The eight slots are searched in order: one holding the project
    already ends the search, else the first nil slot takes it.

  Status stored:
    status_$ok: the project is in the list
    status_$no_right_to_perform_operation: the caller is not a
      super-user
    status_$project_list_is_full: all eight slots hold other projects
}

procedure acl_$add_proj(in proj_acl: uid_$t; out status_ret: status_$t);
var
  i: integer;
begin
  if not acl_$check_suser_pid(proc1_$current) then begin
    status_ret.all := status_$no_right_to_perform_operation;
    return;
  end;

  status_ret.all := status_$ok;

  for i := 1 to 8 do begin
    if acl_$proj_uids[proc1_$current][i] = proj_acl then
      return;
    if acl_$proj_uids[proc1_$current][i] = uid_$nil then begin
      acl_$proj_uids[proc1_$current][i] := proj_acl;
      return;
    end;
  end;

  status_ret.all := status_$project_list_is_full;
end;
