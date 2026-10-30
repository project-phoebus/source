{ ACL_$DELETE_PROJ - delete a project from the current process's list.

  Image addresses:
    sau2  0x00E47F54  ACL_$DELETE_PROJ

  - The slots after the project move up one place, through the first
    nil one, and the eighth is cleared; a nil slot before the project
    ends the search.

  Status stored:
    status_$ok: the project is not in the list
    status_$no_right_to_perform_operation: the caller is not a
      super-user
}

procedure acl_$delete_proj(in proj_acl: uid_$t; out status_ret: status_$t);
var
  i: integer;
  j: integer;                             { the induction registers }
begin
  if not acl_$check_suser_pid(proc1_$current) then begin
    status_ret.all := status_$no_right_to_perform_operation;
    return;
  end;

  status_ret.all := status_$ok;

  for i := 1 to 8 do begin
    if acl_$proj_uids[proc1_$current][i] = uid_$nil then
      return;
    if acl_$proj_uids[proc1_$current][i] = proj_acl then begin
      { move the later slots up }
      for j := i to 7 do begin
        acl_$proj_uids[proc1_$current][j] :=
          acl_$proj_uids[proc1_$current][j + 1];
        if acl_$proj_uids[proc1_$current][j] = uid_$nil then
          exit;
      end;
      acl_$proj_uids[proc1_$current][8] := uid_$nil;
      return;
    end;
  end;
end;
