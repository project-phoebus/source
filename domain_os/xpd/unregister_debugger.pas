{ xpd_$unregister_debugger - free an address space's debugger slot.

  Image addresses:
    sau2  0x00E74F7C  xpd_$unregister_debugger (module-local)

  - Under the XPD lock the address space's slot is freed, and every
    target record 1..57 attached to it detached, each with an event
    pending continued with response 2.

  Status stored:
    status_$ok: the slot was freed
    status_$xpd_not_a_debugger: no slot for the address space
}

[section(proc2_delete_pro, proc2_delete_dat)]
procedure xpd_$unregister_debugger(asid: integer; out status_ret: status_$t);
  internal;
var
  cont_status: status_$t;
  slot: integer;
  i: integer;
  unused_1c: array[1..3] of integer32;    { the TODO in
                                            xpd/find_debugger_index.pas }
begin
  ml_$lock(ml_$xpd_lock);

  for slot := 1 to 6 do
    if xpd_$debuggers[slot].asid = asid then begin
      xpd_$debuggers[slot].asid := 0;
      for i := 1 to 57 do
        with xpd_$targets[i] do
          if state.debugger = slot then begin
            state.debugger := 0;
            if state.event <> 0 then
              xpd_$continue_proc(proc2_$uid[i], 2, cont_status);
          end;
      ml_$unlock(ml_$xpd_lock);
      status_ret.all := status_$ok;
      return;
    end;

  ml_$unlock(ml_$xpd_lock);
  status_ret.all := status_$xpd_not_a_debugger;
end;
