{ PROC2_$SIGNAL_PGROUP - send a signal to a process group, with the
  permission check.

  Image addresses:
    sau2  0x00E3F23E  PROC2_$SIGNAL_PGROUP

  - Under ml_$proc2_lock the group's index is found
    (proc2_$uid_to_pgroup_index) and proc2_$signal_pgroup_internal called
    with the check.

  Status stored:
    proc2_$signal_pgroup_internal's status: always
}

procedure proc2_$signal_pgroup(pgroup_uid: uid_$t; signal: integer;
                               param: status_$t;
                               out status_ret: status_$t);
var
  uid: uid_$t;
  status: status_$t;
begin
  uid := pgroup_uid;
  ml_$lock(ml_$proc2_lock);
  proc2_$signal_pgroup_internal(proc2_$uid_to_pgroup_index(uid), signal,
                                param, true, status);
  ml_$unlock(ml_$proc2_lock);
  status_ret := status;
end;
