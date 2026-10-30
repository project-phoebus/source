{ XPD_$PUT_FP - restore a stopped target's FP state from its save area.

  Image addresses:
    sau2  0x00E5C094  XPD_$PUT_FP

  - XPD_$GET_FP with XPD_$PUT_FP_INT, the same read of slot 0 (above).

  Status stored:
    PROC2_$FIND_ASID's status: not found
    status_$ok: restored
    status_$xpd_target_not_suspended: not a stopped target
}

procedure xpd_$put_fp(in proc_uid: uid_$t; out status_ret: status_$t);
var
  target: integer;
begin
  target := proc2_$find_asid(proc_uid, false, status_ret);
  if target <> 0 then
    with xpd_$targets[target] do
      if (xpd_$debuggers[state.debugger].asid = proc1_$as_id) and then
         (state.event <> 0) and then
         (xpd_state_enabled in state.bits) and then
         (state.debugger <> 0) then
        xpd_$put_fp_int(target, status_ret)
      else
        status_ret.all := status_$xpd_target_not_suspended;
end;
