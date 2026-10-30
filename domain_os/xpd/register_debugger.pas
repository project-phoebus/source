{ xpd_$register_debugger - claim a debugger slot for an address space.

  Image addresses:
    sau2  0x00E5BB1E  xpd_$register_debugger (module-local)

  - Under the XPD lock one pass over the six slots finds the first free
    one and refuses an address space already registered (its slot
    returned).  The free slot gets the address space and its
    eventcount's value is zeroed; with none the result is 0.

  Status stored:
    status_$ok: registered
    status_$xpd_already_a_debugger: already registered
    status_$xpd_debugger_table_full: no free slot
}

function xpd_$register_debugger(asid: integer; out status_ret: status_$t): integer;
  internal;
var
  free_slot: integer;
  slot: integer;
  unused_10: integer32;                   { the TODO in
                                            xpd/find_debugger_index.pas }
begin
  ml_$lock(ml_$xpd_lock);

  free_slot := 0;
  for slot := 1 to 6 do
    if xpd_$debuggers[slot].asid = 0 then begin
      if free_slot = 0 then
        free_slot := slot;
    end
    else if xpd_$debuggers[slot].asid = asid then begin
      ml_$unlock(ml_$xpd_lock);
      status_ret.all := status_$xpd_already_a_debugger;
      xpd_$register_debugger := slot;
      return;
    end;

  if free_slot = 0 then begin
    ml_$unlock(ml_$xpd_lock);
    status_ret.all := status_$xpd_debugger_table_full;
    xpd_$register_debugger := 0;
    return;
  end;

  xpd_$debuggers[free_slot].asid := asid;
  xpd_$debuggers[free_slot].ec.value := 0;
  ml_$unlock(ml_$xpd_lock);
  status_ret.all := status_$ok;
  xpd_$register_debugger := free_slot;
end;
