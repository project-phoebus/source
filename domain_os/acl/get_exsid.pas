{ ACL_$GET_EXSID - the current process's extended SID.

  Image addresses:
    sau2  0x00E48972  ACL_$GET_EXSID

  - The current SID block, then the eight project UIDs from
    ACL_$GET_PROJ_LIST, whatever its count.

  Status stored:
    acl_$get_proj_list's status: always
}

procedure acl_$get_exsid(out exsid: acl_$exsid_t; out status: status_$t);
var
  projs: acl_$proj_uids_t;
  count: integer;                         { not read }
begin
  exsid.sids := acl_$current_sids[proc1_$current];

  acl_$get_proj_list(projs, 8, count, status);

  exsid.proj_uids := projs;
end;
