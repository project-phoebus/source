{ PROC2_$OVERRIDE_DEBUG - make the caller the debugger of a process,
  whatever debugger it has.

  Image addresses:
    sau2  0x00E41722  PROC2_$OVERRIDE_DEBUG

  - PROC2_$DEBUG without the already-debugged test.

  Status stored:
    status_$ok: the debugger was set
    proc2_$find_index' status: no such process
    status_$proc2_permission_denied: ACL_$CHECK_DEBUG_RIGHTS refused
}

procedure proc2_$override_debug(in proc_uid: uid_$t;
                                out status_ret: status_$t);
var
  uid: uid_$t;
  status: status_$t;
  target_idx: integer;
begin
  status.all := status_$ok;
  uid := proc_uid;
  ml_$lock(ml_$proc2_lock);
  if uid = uid_$nil then
    with proc2_$info_table[proc2_$pid_to_index[proc1_$current]] do

      debug_setup_internal(self_index, parent_pgroup_idx, false)

  else begin
    target_idx := proc2_$find_index(uid, status);
    if status.all = status_$ok then
      if acl_$check_debug_rights(proc1_$current,
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
