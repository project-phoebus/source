{ ACL_$SET_RE_ALL_SIDS - set the current process's original and current
  SIDs and project lists.

  Image addresses:
    sau2  0x00E481AE  ACL_$SET_RE_ALL_SIDS
    sau9  0x3C44F87C  ACL_$SET_RE_ALL_SIDS

  - A process that is not a super-user may set each original SID only
    to its original or current one, each current SID to its current,
    original or saved one.
  - A changed original group SID is mirrored in the project list; a
    changed original block is stored as the saved SIDs too.  A change
    or a refusal is audited (AUDIT_$SET_SID_EU) when auditing is on.
  - The project-list changes' statuses are overwritten with status_$ok.

  Status stored:
    status_$ok: the SIDs were set
    status_$no_right_to_perform_operation: a SID the caller may not take
}

procedure acl_$set_re_all_sids(in new_original_sids: acl_sid_block_t;
                               in new_current_sids: acl_sid_block_t;
                               in new_saved_proj: acl_proj_list_t;
                               in new_current_proj: acl_proj_list_t;
                               out status_ret: status_$t);
label
  10;
type
  { The audit record, 0x90 bytes: the SIDs before and after. }
  acl_$set_re_sids_audit_t = record
    old_original: acl_sid_block_t;        { 0x00 }
    old_current: acl_sid_block_t;         { 0x24 }
    new_original: acl_sid_block_t;        { 0x48 }
    new_current: acl_sid_block_t;         { 0x6C }
  end;
var
  aud: acl_$set_re_sids_audit_t;
  audit_flag: pinteger;
begin
  status_ret.all := status_$no_right_to_perform_operation;

  { the audit snapshot }
  if audit_$enabled then begin
    audit_flag := 1;
    aud.old_original := acl_$original_sids[proc1_$current];
    aud.old_current := acl_$current_sids[proc1_$current];
  end;

  with acl_$original_sids[proc1_$current]: orig,
       acl_$current_sids[proc1_$current]: curr,
       acl_$saved_sids[proc1_$current]: saved,
       acl_$saved_proj[proc1_$current]: sproj,
       acl_$proj_lists[proc1_$current]: cproj do begin
    { the gate for a process not a super-user }
    if not acl_$check_suser_pid(proc1_$current) then begin
      { a new original SID must be held already }
      if (new_original_sids.user_sid <> orig.user_sid) and then
         (new_original_sids.user_sid <> curr.user_sid) then
        goto 10;
      if (new_original_sids.group_sid <> orig.group_sid) and then
         (new_original_sids.group_sid <> curr.group_sid) then
        goto 10;
      if (new_original_sids.org_sid <> orig.org_sid) and then
         (new_original_sids.org_sid <> curr.org_sid) then
        goto 10;
      if (new_original_sids.login_sid <> orig.login_sid) and then
         (new_original_sids.login_sid <> curr.login_sid) then
        goto 10;

      { and a new current SID }
      if (new_current_sids.user_sid <> curr.user_sid) and then
         (new_current_sids.user_sid <> orig.user_sid) and then
         (new_current_sids.user_sid <> saved.user_sid) then
        goto 10;
      if (new_current_sids.group_sid <> curr.group_sid) and then
         (new_current_sids.group_sid <> orig.group_sid) and then
         (new_current_sids.group_sid <> saved.group_sid) then
        goto 10;
      if (new_current_sids.org_sid <> curr.org_sid) and then
         (new_current_sids.org_sid <> orig.org_sid) and then
         (new_current_sids.org_sid <> saved.org_sid) then
        goto 10;
      if (new_current_sids.login_sid <> curr.login_sid) and then
         (new_current_sids.login_sid <> orig.login_sid) and then
         (new_current_sids.login_sid <> saved.login_sid) then
        goto 10;
    end;

    { a new original group into the project
      list }
    if (new_original_sids.group_sid <> orig.group_sid) and then
       (new_original_sids.group_sid <> new_current_sids.group_sid) then begin
      acl_$super_count[proc1_$current] :=
        acl_$super_count[proc1_$current] + 1;
      acl_$delete_proj(orig.group_sid, status_ret);
      acl_$add_proj(new_original_sids.group_sid, status_ret);
      acl_$super_count[proc1_$current] :=
        acl_$super_count[proc1_$current] - 1;
    end;

    if orig <> new_original_sids then
      saved := new_original_sids;

    orig := new_original_sids;
    curr := new_current_sids;
    sproj := new_saved_proj;
    cproj := new_current_proj;

    status_ret.all := status_$ok;
    audit_flag := 0;
  end;

  { the audit tail }
10:
  if audit_$enabled then begin
    if (aud.old_current = acl_$current_sids[proc1_$current]) and then
       (status_ret.all = status_$ok) and then
       (aud.old_original = acl_$original_sids[proc1_$current]) then
      return;
    aud.new_original := acl_$original_sids[proc1_$current];
    aud.new_current := acl_$current_sids[proc1_$current];
    audit_$log_event_s(audit_$set_sid_eu, audit_flag, aud.old_current,
                       status_ret, aud, 16#90);
  end;
end;
