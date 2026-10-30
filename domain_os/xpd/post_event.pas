{ XPD_$POST_EVENT - a target tells its debugger about an event and
  waits for the response.

  Image addresses:
    sau2  0x00E75090  XPD_$POST_EVENT

  - Without a debugger slot or not enabled, the response is 2 (none).
  - Else the event code and status are stored, the debugger's
    eventcount advanced, and the process waits on its own for 1; the
    response is the debugger's, from the state word.
  - The event code is merged unmasked.

  Status stored: none.
}

[section(proc2_delete_pro, proc2_delete_dat)]
procedure xpd_$post_event(in event_type: pinteger; in status_val: univ status_$t;
                          out response_ret: pinteger);
begin
  with xpd_$targets[proc1_$as_id] do begin
    if (state.debugger = 0) or else
       not (xpd_state_enabled in state.bits) then begin
      response_ret := 2;
      return;
    end;

    ec.value := 0;
    state.event := event_type;
    status := status_val;
    state.acked := false;

    ec_$advance(xpd_$debuggers[state.debugger].ec);
    discard(ec_$wait(addr(ec), addr(ec_$nil_ec), addr(ec_$nil_ec), 1, 0, 0));

    response_ret := state.response;
  end;
end;
