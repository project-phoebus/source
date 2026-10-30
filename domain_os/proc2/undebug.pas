{ PROC2_$UNDEBUG - detach the caller from a process it debugs.

  Image addresses:
    sau2  0x00E41810  PROC2_$UNDEBUG

  - Under ml_$proc2_lock a process the caller debugs is detached
    (debug_clear_internal, flag true).

  Status stored:
    status_$ok: it was detached
    proc2_$find_index' status: no such process
    status_$proc2_proc_not_debug_target: the caller is not its debugger
}

procedure proc2_$undebug(in proc_uid: uid_$t; out status_ret: status_$t);
var
  uid: uid_$t;
  status: status_$t;
  proc_idx: integer;
begin
  status.all := status_$ok;
  uid := proc_uid;
  ml_$lock(ml_$proc2_lock);
  proc_idx := proc2_$find_index(uid, status);
  if status.all = status_$ok then
    if proc2_$info_table[proc_idx].debugger_idx <>
       proc2_$pid_to_index[proc1_$current] then
      status.all := status_$proc2_proc_not_debug_target
    else
      debug_clear_internal(proc_idx, true);
  ml_$unlock(ml_$proc2_lock);
  status_ret := status;
end;
