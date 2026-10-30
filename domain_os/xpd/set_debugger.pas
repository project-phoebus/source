{ XPD_$SET_DEBUGGER - establish or break a debugger-target link.

  Image addresses:
    sau2  0x00E5BBD8  XPD_$SET_DEBUGGER

  - Both UIDs nil: nothing.  Target nil: the debugger is registered.
    Debugger nil: the target is detached (continued with response 2 if
    an event is pending).  The same process on both sides: the debugger
    is unregistered.
  - Else the debugger's slot goes into the target's state word, also
    when it had one already (then "illegal target setup").
  - Detaching continues the target and then overwrites
    XPD_$CONTINUE_PROC's status.

  Status stored:
    status_$ok: linked or detached
    status_$xpd_debugger_not_found: the debugger's process is not found
    status_$xpd_illegal_target_setup: the target had a debugger
    the callee's status: from PROC2_$FIND_ASID (not found), or from
      registering, unregistering or finding the debugger's slot
}

procedure xpd_$set_debugger(debugger_uid: uid_$t; target_uid: uid_$t;
                            out status_ret: status_$t);
label
  10;
var
  st: status_$t;
  target: integer;
  slot: integer;
  dbg_asid: integer;
begin
  { no target: register the debugger }
  if uid_$nil = target_uid then begin
    if uid_$nil = debugger_uid then
      goto 10;
    dbg_asid := proc2_$find_asid(debugger_uid, false, status_ret);
    if status_ret.all <> status_$ok then
      return;
    discard(xpd_$register_debugger(dbg_asid, status_ret));
    return;
  end;

  target := proc2_$find_asid(target_uid, false, st);
  if st.all <> status_$ok then begin
    status_ret := st;
    return;
  end;

  if uid_$nil = debugger_uid then
    { detach }
    with xpd_$targets[target] do begin
      ml_$lock(ml_$xpd_lock);
      if state.debugger <> 0 then begin
        state.debugger := 0;
        if state.event <> 0 then begin
          ml_$unlock(ml_$xpd_lock);
          xpd_$continue_proc(target_uid, 2, status_ret);
          goto 10;
        end;
      end;
    end
  else begin
    { attach }
    dbg_asid := proc2_$find_asid(debugger_uid, false, st);
    if st.all <> status_$ok then begin
      status_ret.all := status_$xpd_debugger_not_found;
      return;
    end;
    if debugger_uid = target_uid then begin
      xpd_$unregister_debugger(dbg_asid, status_ret);
      return;
    end;
    slot := xpd_$find_debugger_index(dbg_asid, status_ret);
    if slot = 0 then
      return;
    ml_$lock(ml_$xpd_lock);
    if xpd_$targets[target].state.debugger <> 0 then begin
      xpd_$targets[target].state.debugger := slot;
      ml_$unlock(ml_$xpd_lock);
      status_ret.all := status_$xpd_illegal_target_setup;
      return;
    end;
    xpd_$targets[target].state.debugger := slot;
  end;

  ml_$unlock(ml_$xpd_lock);
10:
  status_ret.all := status_$ok;
end;
