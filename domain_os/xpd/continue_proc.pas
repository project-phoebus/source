{ XPD_$CONTINUE_PROC - let a stopped target go on.

  Image addresses:
    sau2  0x00E5BED8  XPD_$CONTINUE_PROC

  - For a target found with an event pending, the debugger's response
    is stored, the event cleared and the target's eventcount advanced.
  - The response's low byte is merged unmasked.

  Status stored:
    PROC2_$FIND_ASID's status: the target was continued, or not found
    status_$xpd_target_not_suspended: no event pending
}

procedure xpd_$continue_proc(in proc_uid: uid_$t; in response: pinteger;
                             out status_ret: status_$t);
var
  target: integer;
begin
  target := proc2_$find_asid(proc_uid, false, status_ret);
  if target <> 0 then
    with xpd_$targets[target] do
      if state.event = 0 then
        status_ret.all := status_$xpd_target_not_suspended
      else begin
        state.response := response;
        state.event := 0;
        ec_$advance(ec);
      end;
end;
