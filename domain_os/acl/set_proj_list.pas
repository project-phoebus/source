{ ACL_$SET_PROJ_LIST - set the current process's project list.

  Image addresses:
    sau2  0x00E480F4  ACL_$SET_PROJ_LIST

  - A negative count is taken as 0; the first count slots take the
    caller's projects and the rest of the eight are cleared.

  Status stored:
    status_$ok: the list was set
    status_$no_right_to_perform_operation: the caller is not a
      super-user
    status_$acl_proj_list_too_big: a count above eight
}

procedure acl_$set_proj_list(in proj_acls: acl_$proj_uids_t;
                             in count: integer;
                             out status_ret: status_$t);
var
  num: integer;
  i: integer;                             { the induction registers }
begin
  if not acl_$check_suser_pid(proc1_$current) then begin
    status_ret.all := status_$no_right_to_perform_operation;
    return;
  end;

  num := max(count, 0);
  if num > 8 then begin
    status_ret.all := status_$acl_proj_list_too_big;
    return;
  end;

  status_ret.all := status_$ok;

  { the caller's projects }
  for i := 1 to num do
    acl_$proj_uids[proc1_$current][i] := proj_acls[i];

  { the rest cleared }
  for i := num + 1 to 8 do
    acl_$proj_uids[proc1_$current][i] := uid_$nil;
end;
