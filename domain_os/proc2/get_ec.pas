{ PROC2_$GET_EC - register a process's signal-delivery eventcount with EC2.

  Image addresses:
    sau2  0x00E400C2  PROC2_$GET_EC

  - Only key 0.  Under ml_$proc2_lock the process's FIM delivery
    eventcount (FIM_$DELIV_EC[asid]) is registered; the handle is nil
    when the lookup failed.

  Status stored:
    proc2_$find_index' or ec2_$register_ec1's status: key 0
    status_$proc2_bad_eventcount_key: another key
}

procedure proc2_$get_ec(in proc_uid: uid_$t;
                        in key: integer;
                        out ec_ret: univ_ptr;
                        out status_ret: status_$t);
var
  ec: ec2_$ptr_t;
  status: status_$t;
  idx: integer;
begin
  if key <> 0 then begin
    status_ret.all := status_$proc2_bad_eventcount_key;
    return;
  end;
  ml_$lock(ml_$proc2_lock);
  idx := proc2_$find_index(proc_uid, status);
  if status.all = status_$ok then
    ec := ec2_$register_ec1(
            addr(fim_$deliv_ec[proc2_$info_table[idx].asid]),
            status)
  else
    ec := nil;
  ml_$unlock(ml_$proc2_lock);
  ec_ret := ec;
  status_ret := status;
end;

