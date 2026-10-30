{ PROC2_$SIGNAL - send a signal to a process.

  Image addresses:
    sau2  0x00E3EFA0  PROC2_$SIGNAL

  - Under ml_$proc2_lock: allowed for the target's debugger, a SIGCONT
    within the caller's session (not 0), or by ACL_$CHECK_FAULT_RIGHTS;
    posted unless the target is a zombie.  The attempt is logged (event
    type 1).

  Status stored:
    proc2_$deliver_signal_internal's status: the signal was posted
    proc2_$find_index' status: the lookup's (a zombie, or not found)
    status_$proc2_permission_denied: it was refused
}

procedure proc2_$signal(proc_uid: uid_$t;
                        in signal: integer;
                        param: status_$t;
                        out status_ret: status_$t);
var
  status: status_$t;
  index: integer;
  current: proc2_info_ptr_t;
  target: proc2_info_ptr_t;
begin
  ml_$lock(ml_$proc2_lock);
  index := proc2_$find_index(proc_uid, status);
  current := addr(proc2_$info_table[
               proc2_$pid_to_index[proc1_$current]]);
  target := addr(proc2_$info_table[index]);
  if (status.all = status_$ok)
     or else (status.all = status_$proc2_zombie) then
    if (target^.debugger_idx = current^.self_index)
       or else ((target^.session_id = current^.session_id)
                and then (signal = proc2_$sig_cont)
                and then (target^.session_id <> 0))
       or else acl_$check_fault_rights(current^.level1_pid,
                                       target^.level1_pid) then

      begin
        if status.all = status_$ok then
          proc2_$deliver_signal_internal(index, signal, param,
                                         status);
      end
    else
      status.all := status_$proc2_permission_denied;
  ml_$unlock(ml_$proc2_lock);
  status_ret := status;
  proc2_$log_signal_event(proc2_signal_event_process, index, signal,
                          param, status);
end;
