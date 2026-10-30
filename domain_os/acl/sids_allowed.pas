{ acl_$sids_allowed - whether a SID block is one a process may take.

  Image addresses:
    sau2  0x00E44CE8  acl_$sids_allowed (module-local)

  - The user, group and organization SIDs must each be the process's
    current or saved one, and the login SID nil, the saved or the
    original one.

  Status stored: none.
}

function acl_$sids_allowed(in sids: acl_sid_block_t; pid: integer):
  boolean; internal;
begin
  acl_$sids_allowed := false;

  if (sids.user_sid <> acl_$current_sids[pid].user_sid) and then
     (sids.user_sid <> acl_$saved_sids[pid].user_sid) then
    return;

  if (sids.group_sid <> acl_$current_sids[pid].group_sid) and then
     (sids.group_sid <> acl_$saved_sids[pid].group_sid) then
    return;

  if (sids.org_sid <> acl_$current_sids[pid].org_sid) and then
     (sids.org_sid <> acl_$saved_sids[pid].org_sid) then
    return;

  if (sids.login_sid = uid_$nil) or else
     (sids.login_sid = acl_$saved_sids[pid].login_sid) or else
     (sids.login_sid = acl_$original_sids[pid].login_sid) then
    acl_$sids_allowed := true;
end;
