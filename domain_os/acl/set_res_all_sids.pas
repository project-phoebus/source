{ ACL_$SET_RES_ALL_SIDS - set the current process's original, current
  and saved SIDs and project lists.

  Image addresses:
    sau2  0x00E4855A  ACL_$SET_RES_ALL_SIDS
    sau9  0x3C44FC3E  ACL_$SET_RES_ALL_SIDS

  - The super-user sibling of ACL_$SET_RE_ALL_SIDS: a changed original
    group SID is mirrored in the project list, and the change or a
    refusal audited.
  - The project-list changes' statuses are overwritten with status_$ok.

  Status stored:
    status_$ok: the SIDs were set
    status_$no_right_to_perform_operation: the caller is not a
      super-user
}

procedure acl_$set_res_all_sids(in new_original_sids: acl_sid_block_t;
                                in new_current_sids: acl_sid_block_t;
                                in new_saved_sids: acl_sid_block_t;
                                in new_saved_proj: acl_proj_list_t;
                                in new_current_proj: acl_proj_list_t;
                                out status_ret: status_$t);
label
  10;
type
  { The audit record, 0xD8 bytes: the SIDs before and after. }
  acl_$set_res_sids_audit_t = record
    old_original: acl_sid_block_t;        { 0x00 }
    old_current: acl_sid_block_t;         { 0x24 }
    old_saved: acl_sid_block_t;           { 0x48 }
    new_original: acl_sid_block_t;        { 0x6C }
    new_current: acl_sid_block_t;         { 0x90 }
    new_saved: acl_sid_block_t;           { 0xB4 }
  end;
var
  aud: acl_$set_res_sids_audit_t;
  audit_flag: pinteger;
begin
  status_ret.all := status_$no_right_to_perform_operation;

  { the audit snapshot }
  if audit_$enabled then begin
    audit_flag := 1;
    aud.old_original := acl_$original_sids[proc1_$current];
    aud.old_current := acl_$current_sids[proc1_$current];
    aud.old_saved := acl_$saved_sids[proc1_$current];
  end;

  with acl_$original_sids[proc1_$current]: orig,
       acl_$current_sids[proc1_$current]: curr,
       acl_$saved_sids[proc1_$current]: saved,
       acl_$saved_proj[proc1_$current]: sproj,
       acl_$proj_lists[proc1_$current]: cproj do begin
    { super-users only; the refusal is logged }
    if not acl_$check_suser_pid(proc1_$current) then
      goto 10;

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

    orig := new_original_sids;
    curr := new_current_sids;
    saved := new_saved_sids;
    sproj := new_saved_proj;
    cproj := new_current_proj;

    status_ret.all := status_$ok;
    audit_flag := 0;
  end;

  { the audit tail }
10:
  if audit_$enabled then begin
    if (aud.old_saved = acl_$saved_sids[proc1_$current]) and then
       (aud.old_current = acl_$current_sids[proc1_$current]) and then
       (status_ret.all = status_$ok) and then
       (aud.old_original = acl_$original_sids[proc1_$current]) then
      return;
    aud.new_original := acl_$original_sids[proc1_$current];
    aud.new_current := acl_$current_sids[proc1_$current];
    aud.new_saved := acl_$saved_sids[proc1_$current];
    audit_$log_event_s(audit_$set_sid_eu, audit_flag, aud.old_current,
                       status_ret, aud, 16#D8);
  end;
end;
