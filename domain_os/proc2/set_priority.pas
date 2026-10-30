{ PROC2_$SET_PRIORITY - set a process's priority range.

  Image addresses:
    sau2  0x00E414DE  PROC2_$SET_PRIORITY

  - The two priorities are ordered (unsigned); under ml_$proc2_lock the
    found process's range goes to PROC1_$SET_PRIORITY.

  Status stored:
    proc2_$find_index' status: always
}

procedure proc2_$set_priority(in proc_uid: uid_$t;
                              in priority_1: pinteger;
                              in priority_2: pinteger;
                              out status_ret: status_$t);
var
  status: status_$t;
  max_priority: integer;
  min_priority: integer;
  index: integer;
  prio: pinteger;
begin
  prio := priority_1;
  if prio < priority_2 then begin
    min_priority := prio;
    max_priority := priority_2;
  end
  else begin
    min_priority := priority_2;
    max_priority := prio;
  end;
  ml_$lock(ml_$proc2_lock);
  index := proc2_$find_index(proc_uid, status);
  if status.code = 0 then
    proc1_$set_priority(proc2_$info_table[index].level1_pid, true,
                        min_priority, max_priority);
  ml_$unlock(ml_$proc2_lock);
  status_ret := status;
end;
