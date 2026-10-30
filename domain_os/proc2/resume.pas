{ PROC2_$RESUME - resume a suspended process.

  Image addresses:
    sau2  0x00E413DA  PROC2_$RESUME

  - Under ml_$proc2_lock the process is found and PROC1_$RESUME asked to
    resume it.

  Status stored:
    proc1_$resume's status: the process was resumed
    proc2_$find_index' status: no such process
    status_$proc2_not_suspended: it was not suspended
    proc1_$resume's status, fail bit set: another error
}

procedure proc2_$resume(in proc_uid: uid_$t; out status_ret: status_$t);
var
  status: status_$t;
  index: integer;
begin
  ml_$lock(ml_$proc2_lock);
  index := proc2_$find_index(proc_uid, status);
  if status.code = 0 then begin
    proc1_$resume(proc2_$info_table[index].level1_pid, status);

    if status.code <> 0 then
      if status.all = status_$process_not_suspended then
        status.all := status_$proc2_not_suspended
      else
        status.fail := true;
  end;
  ml_$unlock(ml_$proc2_lock);
  status_ret := status;
end;
