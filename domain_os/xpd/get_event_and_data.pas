{ XPD_$GET_EVENT_AND_DATA - the next event posted to the caller's
  debugger slot.

  Image addresses:
    sau2  0x00E5BE28  XPD_$GET_EVENT_AND_DATA

  - Of the target records 1..57, the first of the caller's slot with an
    event pending, enabled and not yet acknowledged gives its UID,
    event code and status; the event is acknowledged.  Otherwise event
    0 and the nil UID.
  - The slot lookup's status is not read.

  Status stored:
    the target's event status: an event was found
    status_$ok: none was (also for a caller that is not a debugger)
}

procedure xpd_$get_event_and_data(out proc_uid: uid_$t; out event_type: pinteger;
                                  out status_ret: status_$t);
var
  st: status_$t;
  slot: integer;
  i: integer;
  unused_10: integer32;                   { the TODO in
                                            xpd/find_debugger_index.pas }
begin
  slot := xpd_$find_debugger_index(proc1_$as_id, st);
  if slot <> 0 then
    for i := 1 to 57 do
      with xpd_$targets[i] do
        if (state.debugger = slot) and then
           not (xpd_state_acked in state.bits) and then
           (xpd_state_enabled in state.bits) and then
           (state.event <> 0) then begin
          proc_uid := proc2_$uid[i];
          event_type := state.event;
          status_ret := status;
          state.acked := true;
          return;
        end;

  event_type := 0;
  proc_uid := uid_$nil;
  status_ret.all := status_$ok;
end;
