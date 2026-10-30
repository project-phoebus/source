{ audit_$start_logging - load the audit list, open the log, start the
  server.

  Image addresses:
    sau2  0x00E70C78  audit_$start_logging (module-local)

  - The audit list is loaded, the log opened under the lock, logging
    switched on and the server process created (or, when it is running,
    woken).  If the server cannot be created, logging is off again.

  Status stored:
    status_$audit_event_logging_already_started: logging was on
    audit_$load_list's status: the list was not loaded (status_$ok
      when there is none)
    audit_$open_log's or proc1_$create_p's status: otherwise
}

{ TODO(pascal) 44 frame bytes of audit_$start_logging no object explains

  The SAU2 frame is 0x30 bytes in a routine whose body addresses nothing
  in it (every value is in a register or the callees' frames): 4 bytes
  are the reserved slot of an `internal' routine, the other 44 are held
  by the stand-in unused_30.  Untouched frames are ordinary, but 44 bytes is
  large: the source may have declared locals that the code never needed (a
  status, a message buffer?). }

procedure audit_$start_logging(out status: status_$t); internal;
var
  unused_30: array[1..11] of integer32;   { stand-in }
begin
  if audit_$enabled then
    status.all := status_$audit_event_logging_already_started

  { the list, then the log under the lock }
  else if audit_$load_list(status) and then (status.all = status_$ok)
  then begin
    ml_$exclusion_start(audit_$wired^.lock);
    audit_$open_log(status);
    ml_$exclusion_stop(audit_$wired^.lock);

    if status.all = status_$ok then begin
      audit_$enabled := true;
      if not audit_$server_running then begin
        audit_$server_running := true;
        audit_$server_pid := proc1_$create_p(addr(audit_$server),
                                             16#1400000E, status);
        if status.all <> status_$ok then begin
          audit_$server_running := false;
          audit_$enabled := false;
        end;
      end
      else
        ec_$advance(audit_$wired^.ec);
    end;
  end;
end;
