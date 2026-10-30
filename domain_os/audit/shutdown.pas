{ AUDIT_$SHUTDOWN - stop the audit trail at shutdown.

  Image addresses:
    sau2  0x00E70D1E  AUDIT_$SHUTDOWN

  - The logging is stopped and its status ignored.

  Status stored: none.
}

procedure audit_$shutdown;
var
  status: status_$t;
begin
  audit_$stop_logging(status);
end;
