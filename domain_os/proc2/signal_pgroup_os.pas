{ PROC2_$SIGNAL_PGROUP_OS - send a signal to a process group for the
  system, with no permission check.

  Image addresses:
    sau2  0x00E3F2C2  PROC2_$SIGNAL_PGROUP_OS

  - Under ml_$proc2_lock the group's index is found and
    proc2_$signal_pgroup_internal called without the check.

  Status stored:
    proc2_$signal_pgroup_internal's status: always
}

procedure proc2_$signal_pgroup_os(pgroup_uid: uid_$t; signal: integer;
                                  param: status_$t;
                                  out status_ret: status_$t);
var
  status: status_$t;
begin
  ml_$lock(ml_$proc2_lock);
  proc2_$signal_pgroup_internal(proc2_$uid_to_pgroup_index(pgroup_uid),
                                signal, param, false, status);

  ml_$unlock(ml_$proc2_lock);
  status_ret := status;
end;
