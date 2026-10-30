{ PROC2_$GET_PID - the PROC1 pid of a process UID.

  Image addresses:
    sau2  0x00E40CBA  PROC2_$GET_PID

  - Under ml_$proc2_lock, the found entry's PROC1 pid.
  - A UID not found leaves the result as the caller had it.

  Status stored:
    proc2_$find_index' status: always
}

function proc2_$get_pid(in proc_uid: uid_$t; out status_ret: status_$t): integer;
var
  status: status_$t;
  idx: integer;
begin
  ml_$lock(ml_$proc2_lock);
  idx := proc2_$find_index(proc_uid, status);
  if status.all = status_$ok then
    proc2_$get_pid := proc2_$info_table[idx].level1_pid;
  ml_$unlock(ml_$proc2_lock);
  status_ret := status;
end;
