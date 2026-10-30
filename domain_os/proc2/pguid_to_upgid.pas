{ PROC2_$PGUID_TO_UPGID - the UNIX group id of a process-group UID.

  Image addresses:
    sau2  0x00E41072  PROC2_$PGUID_TO_UPGID

  - proc2_$uid_to_upgid_internal under ml_$proc2_lock.

  Status stored:
    status_$ok: always
}

procedure proc2_$pguid_to_upgid(pgroup_uid: uid_$t;
                                out upgid_ret: pinteger;
                                out status_ret: status_$t);
var
  upgid: pinteger;
begin
  ml_$lock(ml_$proc2_lock);
  upgid := proc2_$uid_to_upgid_internal(pgroup_uid);
  ml_$unlock(ml_$proc2_lock);
  upgid_ret := upgid;
  status_ret.all := status_$ok;
end;
