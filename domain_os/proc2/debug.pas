{ PROC2_$DEBUG - make the caller the debugger of a process.

  Image addresses:
    sau2  0x00E41620  PROC2_$DEBUG

  - Under ml_$proc2_lock: for UID_$NIL the caller becomes the target and
    its parent the debugger; otherwise the UID's process becomes the
    caller's target.

  Status stored:
    status_$ok: the debugger was set
    proc2_$find_index' status: no such process
    status_$proc2_process_already_debugging: it has a debugger
    status_$proc2_permission_denied: ACL_$CHECK_DEBUG_RIGHTS refused
}

procedure proc2_$debug(in proc_uid: uid_$t; out status_ret: status_$t);
var
  uid: uid_$t;
  status: status_$t;
  cur_idx: integer;
  target_idx: integer;
begin
  status.all := status_$ok;
  uid := proc_uid;
  ml_$lock(ml_$proc2_lock);
  if uid = uid_$nil then begin
    cur_idx := proc2_$pid_to_index[proc1_$current];
    debug_setup_internal(cur_idx,
                         proc2_$info_table[cur_idx].parent_pgroup_idx,
                         false);
  end
  else begin
    target_idx := proc2_$find_index(uid, status);
    if status.all = status_$ok then
      if proc2_$info_table[target_idx].debugger_idx <> 0 then

        status.all := status_$proc2_process_already_debugging

      else if acl_$check_debug_rights(proc1_$current,
                proc2_$info_table[target_idx].level1_pid) then

        debug_setup_internal(target_idx,
                             proc2_$pid_to_index[proc1_$current],
                             true)
      else
        status.all := status_$proc2_permission_denied;
  end;
  ml_$unlock(ml_$proc2_lock);
  status_ret := status;
end;
