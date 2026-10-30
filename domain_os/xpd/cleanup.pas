{ XPD_$CLEANUP - the exit path's XPD teardown for the current process.

  Image addresses:
    sau2  0x00E75046  XPD_$CLEANUP

  - Event 3 (exit, a zero status) is posted to the process's debugger,
    if it has one; its own debugger slot, if it is a debugger, is given
    up.
  - The enabled, debugger and event fields of its target record (that
    of PROC1_$AS_ID) are cleared.

  Status stored: none.
}

[section(proc2_delete_pro, proc2_delete_dat)]
procedure xpd_$cleanup;
var
  unreg_status: status_$t;
  response: pinteger;
begin
  xpd_$post_event(3, 0, response);
  xpd_$unregister_debugger(proc1_$as_id, unreg_status);
  xpd_$targets[proc1_$as_id].state.bits :=
    xpd_$targets[proc1_$as_id].state.bits - [5..11, 15];
end;
