{ XPD_$GET_EC - the caller's debugger eventcount, registered with EC2.

  Image addresses:
    sau2  0x00E5BDC2  XPD_$GET_EC

  - The caller's address space must hold a debugger slot and the key be
    0; then the slot's eventcount is registered with EC2_$REGISTER_EC1
    and its handle returned.

  Status stored:
    status_$ok: registered
    status_$xpd_not_a_debugger: the caller is not a debugger
    status_$xpd_invalid_ec_key: a key other than 0
    EC2_$REGISTER_EC1's status, its fail bit set: that failed
}

procedure xpd_$get_ec(in key: integer; out ec_ret: ec2_$ptr_t;
                      out status_ret: status_$t);
var
  slot: integer;
begin
  slot := xpd_$find_debugger_index(proc1_$as_id, status_ret);
  if slot <> 0 then
    if key = 0 then begin
      ec_ret := ec2_$register_ec1(addr(xpd_$debuggers[slot].ec), status_ret);
      if status_ret.all <> status_$ok then
        status_ret.fail := true;
    end
    else
      status_ret.all := status_$xpd_invalid_ec_key;
end;
