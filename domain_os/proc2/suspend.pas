{ PROC2_$SUSPEND - suspend a process.

  Image addresses:
    sau2  0x00E4126A  PROC2_$SUSPEND
    sau2  0x00E4120C  proc2_$suspend_try (nested)

  - Under ml_$proc2_lock: the caller suspends itself with the lock
    dropped; another process is suspended and, when only requested,
    waited for, 120 ticks of TIME_$CLOCKH.
  - The lock is dropped across each wait; at the deadline the process is
    resumed again.
  - The self test indexes the table with PROC1_$CURRENT, a level-1 PID.

  Status stored:
    proc2_$suspend_try's status: the process was suspended
    proc2_$find_index' status: no such process
    status_$proc2_suspend_timed_out: the deadline passed
}

procedure proc2_$suspend(in proc_uid: uid_$t; out status_ret: status_$t);
label
  done;
var
  resume_status: status_$t;
  status: status_$t;
  wait_val: integer32;
  which: integer;
  index: integer;
  suspend_result: boolean;

  { proc2_$suspend_try - one suspension request.

    - PROC1_$SUSPEND for the parent's process; its result (suspended at
      once) goes to the parent's suspend_result.  The result is false on
      an error.
    - Nested in PROC2_$SUSPEND, whose status it writes.

    Status stored:
      proc1_$suspend's status: no error
      status_$proc2_already_suspended: PROC1's "already suspended"
      proc1_$suspend's status, fail bit set: another error
  }

  function proc2_$suspend_try: boolean;
  begin
    proc2_$suspend_try := true;
    suspend_result := proc1_$suspend(
        proc2_$info_table[index].level1_pid, status);
    if status.code <> 0 then begin
      if status.all = status_$process_already_suspended then

        status.all := status_$proc2_already_suspended
      else
        status.fail := true;
      proc2_$suspend_try := false;
    end;
  end;

begin
  ml_$lock(ml_$proc2_lock);
  index := proc2_$find_index(proc_uid, status);
  if status.code = 0 then begin
    if proc_uid = proc2_$info_table[proc1_$current].uid then begin

      ml_$unlock(ml_$proc2_lock);
      discard(proc2_$suspend_try);
      goto done;
    end;
    wait_val := proc1_$suspend_ec.value + 1;
    if proc2_$suspend_try then
      while not suspend_result do begin
        ml_$unlock(ml_$proc2_lock);
        which := ec_$wait(addr(proc1_$suspend_ec),
                          ec_$eventcount_ptr_t(addr(time_$clockh)),
                          addr(ec_$nil_ec), wait_val,
                          time_$clockh + 16#78, 0);
        ml_$lock(ml_$proc2_lock);
        index := proc2_$find_index(proc_uid, status);
        if status.code <> 0 then
          exit;
        if which = 0 then begin
          suspend_result := proc1_$suspendp(
              proc2_$info_table[index].level1_pid, status);
          wait_val := wait_val + 1;
        end
        else begin
          suspend_result := true;
          proc1_$resume(proc2_$info_table[index].level1_pid,
                        resume_status);
          status.all := status_$proc2_suspend_timed_out;
        end;
      end;
  end;
  ml_$unlock(ml_$proc2_lock);
done:
  status_ret := status;
end;
