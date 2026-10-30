{ XPD_$GET_FP - save a stopped target's FP state into its save area.

  Image addresses:
    sau2  0x00E5BFFC  XPD_$GET_FP

  - The found target's record must be the caller's slot's, with an
    event pending, enabled and a slot; then XPD_$GET_FP_INT saves its
    address space's FP state.
  - Slot 0 indexes xpd_$debuggers before the test that refuses it.

  Status stored:
    PROC2_$FIND_ASID's status: not found
    status_$ok: saved
    status_$xpd_target_not_suspended: not a stopped target
}

procedure xpd_$get_fp(in proc_uid: uid_$t; out status_ret: status_$t);
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
        xpd_$get_fp_int(target, status_ret)
      else
        status_ret.all := status_$xpd_target_not_suspended;
end;
