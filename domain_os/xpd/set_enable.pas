{ XPD_$SET_ENABLE - turn event capture for a target on or off.

  Image addresses:
    sau2  0x00E5BF50  XPD_$SET_ENABLE

  - Under the XPD lock the found target's enabled flag is stored;
    enabling clears a pending event, disabling with one pending
    continues the target with response 2.

  Status stored:
    PROC2_$FIND_ASID's or XPD_$CONTINUE_PROC's status: in either case
}

procedure xpd_$set_enable(in proc_uid: uid_$t; in enable: boolean;
                          out status_ret: status_$t);
var
  target: integer;
begin
  target := proc2_$find_asid(proc_uid, false, status_ret);
  ml_$lock(ml_$xpd_lock);

  if target <> 0 then
    with xpd_$targets[target] do begin
      state.enabled := enable;
      if enable then
        state.event := 0
      else if state.event <> 0 then
        xpd_$continue_proc(proc2_$uid[target], 2, status_ret);
    end;

  ml_$unlock(ml_$xpd_lock);
end;
