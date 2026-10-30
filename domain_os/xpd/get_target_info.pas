{ XPD_$GET_TARGET_INFO - whether a process is a debug target, and
  whether an event is pending for it.

  Image addresses:
    sau2  0x00E5C12C  XPD_$GET_TARGET_INFO

  - For a process found, is_target is "enabled and has a debugger slot"
    (a plain `and'); is_suspended is "an event is pending" for a
    target, else false.

  Status stored:
    PROC2_$FIND_ASID's status: in either case
}

procedure xpd_$get_target_info(in proc_uid: uid_$t; out is_target: boolean;
                               out is_suspended: boolean;
                               out status_ret: status_$t);
var
  target: integer;
begin
  target := proc2_$find_asid(proc_uid, false, status_ret);
  if target <> 0 then
    with xpd_$targets[target] do begin
      is_target := (xpd_state_enabled in state.bits) and
                   (state.debugger <> 0);
      if is_target then
        is_suspended := state.event <> 0
      else
        is_suspended := false;
    end;
end;
