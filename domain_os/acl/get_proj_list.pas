{ ACL_$GET_PROJ_LIST - the current process's project list.

  Image addresses:
    sau2  0x00E48034  ACL_$GET_PROJ_LIST

  - Up to max_count (at most eight) slots are copied, until a nil one;
    the array's rest up to max_count is set nil.  The count copied is
    handed back.

  Status stored:
    status_$ok: always
}

procedure acl_$get_proj_list(out proj_acls: acl_$proj_uids_t;
                             in max_count: integer;
                             out count_ret: integer;
                             out status_ret: status_$t);
var
  max: integer;
  count: integer;
  i: integer;                             { the induction registers }
begin
  status_ret.all := status_$ok;
  count := 0;
  max := min(max_count, 8);

  { the list, up to its first nil slot }
  for i := 1 to max do begin
    if acl_$proj_uids[proc1_$current][i] = uid_$nil then
      exit;
    proj_acls[count + 1] := acl_$proj_uids[proc1_$current][i];
    count := count + 1;
  end;

  { the rest of the caller's places }
  for i := count + 1 to max do
    proj_acls[i] := uid_$nil;

  count_ret := count;
end;
