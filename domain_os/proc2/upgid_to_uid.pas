{ PROC2_$UPGID_TO_UID - the UID of a UNIX process group id.

  Image addresses:
    sau2  0x00E4100C  PROC2_$UPGID_TO_UID

  - proc2_$upgid_to_uid_internal under ml_$proc2_lock.

  Status stored:
    status_$ok: always
}

procedure proc2_$upgid_to_uid(in upgid: integer; out uid_ret: uid_$t;
                              out status_ret: status_$t);
var
  uid: uid_$t;
  upgid_val: integer;
begin
  upgid_val := upgid;
  ml_$lock(ml_$proc2_lock);
  uid := proc2_$upgid_to_uid_internal(upgid_val);
  ml_$unlock(ml_$proc2_lock);
  uid_ret := uid;
  status_ret.all := status_$ok;
end;
