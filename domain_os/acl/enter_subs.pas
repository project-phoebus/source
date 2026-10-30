{ ACL_$ENTER_SUBS - enter the protected subsystem an object names.

  Image addresses:
    sau2  0x00E46DA0  ACL_$ENTER_SUBS

  - The caller is trusted as process 1 (which defines the subsystem's
    magic, its return address) or when its magic matches; acl_$setids
    applies or checks the object's set-ID SIDs on copies.
  - A trusted change is committed, and the result is true, unless a
    debugger that is neither a super-user nor allowed the new SIDs
    watches.  A change or a failure is audited.
  - The audit record's "after" SIDs are read back from the current SIDs,
    so a refused change logs the unchanged ones.

  Status stored:
    acl_$setids' status: no refusal
    status_$no_right_to_perform_operation: a debugger refused the change
}

function acl_$enter_subs(uid: uid_$t; out status_ret: status_$t): boolean;
var
  audit_old: acl_sid_block_t;
  audit_new: acl_sid_block_t;
  proj: acl_proj_list_t;
  sids: acl_sid_block_t;
  magic: integer32;
  usp: integer32;
  audit_flag: pinteger;
  trusted: boolean;
  changed: boolean;                       { its value kept for the audit test }
  pid: pinteger;
begin
  acl_$enter_subs := false;
  usp := proc1_$get_usp;
  magic := acl_$long_ptr_t(usp)^;

  if audit_$enabled then
    audit_old := acl_$current_sids[proc1_$current];

  if proc1_$current = 1 then begin
    acl_$subs_magic := magic;
    trusted := true;
  end
  else
    trusted := acl_$subs_magic = magic;

  sids := acl_$current_sids[proc1_$current];
  proj := acl_$proj_lists[proc1_$current];
  acl_$setids(uid, trusted, sids, proj, changed, status_ret);

  if changed and then trusted then begin
    pid := proc2_$get_debugger_pid;
    if (pid <> 0) and then not acl_$check_suser_pid(pid) and then
       not acl_$sids_allowed(sids, pid) then
      status_ret.all := status_$no_right_to_perform_operation
    else begin
      acl_$saved_sids[proc1_$current] := sids;
      acl_$current_sids[proc1_$current] := sids;
      acl_$proj_lists[proc1_$current] := proj;
      acl_$enter_subs := true;
    end;
  end;

  if audit_$enabled and then
     (changed or else (status_ret.all <> status_$ok)) then begin
    audit_new := acl_$current_sids[proc1_$current];
    if status_ret.all = status_$ok then
      audit_flag := 0
    else
      audit_flag := 1;
    audit_$log_event_s(audit_$enter_subs_eu, audit_flag, audit_old,
                       status_ret, audit_new, 16#24);
  end;
end;
