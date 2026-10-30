{ xpd_$find_debugger_index - the debugger slot registered for an
  address space.

  Image addresses:
    sau2  0x00E5BADC  xpd_$find_debugger_index (module-local)

  - The six slots are searched for the address space; the result is its
    slot, or 0.

  Status stored:
    status_$ok: found
    status_$xpd_not_a_debugger: none
}

{ TODO(pascal) frame bytes of XPD's search loops nothing explains

  xpd_$find_debugger_index, xpd_$register_debugger,
  XPD_$GET_EVENT_AND_DATA and xpd_$unregister_debugger leave 4, 4, 4
  and 12 frame bytes no instruction addresses.  Their loops may be
  `with' statements over the slot (a temporary each) under another
  parameter name.  The stand-ins unused_c, unused_10 (twice) and
  unused_1c hold the places. }

function xpd_$find_debugger_index(asid: integer; out status_ret: status_$t): integer;
  internal;
var
  slot: integer;
  unused_c: integer32;                    { the TODO }
begin
  for slot := 1 to 6 do
    if xpd_$debuggers[slot].asid = asid then begin
      xpd_$find_debugger_index := slot;
      status_ret.all := status_$ok;
      return;
    end;

  status_ret.all := status_$xpd_not_a_debugger;
  xpd_$find_debugger_index := 0;
end;
