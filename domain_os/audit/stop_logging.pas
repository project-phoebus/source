{ audit_$stop_logging - stop the audit logging.

  Image addresses:
    sau2  0x00E70D38  audit_$stop_logging (module-local)

  - Logging is switched off, the server woken (it sees the flag and
    ends), and the log closed under the lock.

  Status stored:
    status_$ok: logging was on, whatever the close stored
    status_$audit_event_logging_already_stopped: logging was off
}

{ TODO(pascal) 8 frame bytes of audit_$stop_logging no object explains

  The SAU2 frame has nothing addressed: the reserved slot of an
  `internal' routine and 8 more bytes, held by the stand-ins unused_8
  and unused_c (two longwords, not one 8-byte object, which the 8-byte
  alignment lead would place lower; as audit_$start_logging's 44, see the
  TODO(pascal) in audit/start_logging.pas). }

procedure audit_$stop_logging(out status: status_$t); internal;
var
  unused_8: integer32;                    { stand-in }
  unused_c: integer32;                    { stand-in }
begin
  if not audit_$enabled then
    status.all := status_$audit_event_logging_already_stopped
  else begin
    audit_$enabled := false;
    ec_$advance(audit_$wired^.ec);
    ml_$exclusion_start(audit_$wired^.lock);
    audit_$close_log(status);
    ml_$exclusion_stop(audit_$wired^.lock);
    status.all := status_$ok;
  end;
end;
