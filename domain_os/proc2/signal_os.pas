{ PROC2_$SIGNAL_OS - send a signal to a process for the system, with no
  permission check.

  Image addresses:
    sau2  0x00E3F0A6  PROC2_$SIGNAL_OS

  - Under ml_$proc2_lock the found target gets the signal
    (proc2_$deliver_signal_internal); the attempt is logged (event type
    1).

  Status stored:
    proc2_$deliver_signal_internal's status: the target was found
    proc2_$find_index' status: it was not
}

procedure proc2_$signal_os(in proc_uid: uid_$t; in signal: integer;
                           in param: univ status_$t;
                           out status_ret: status_$t);
var
  param_copy: status_$t;
  status: status_$t;
  index: integer;
begin
  param_copy := param;
  ml_$lock(ml_$proc2_lock);
  index := proc2_$find_index(proc_uid, status);
  if status.all = status_$ok then
    proc2_$deliver_signal_internal(index, signal, param_copy,
                                   status);
  ml_$unlock(ml_$proc2_lock);
  status_ret := status;
  proc2_$log_signal_event(proc2_signal_event_process, index, signal,
                          param, status);
end;
