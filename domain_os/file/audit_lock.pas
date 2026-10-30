{ file_$audit_lock - log an audit event for a lock request.

  Image addresses:
    sau2  0x00E5E88A  file_$audit_lock

  - The event (16#40009, 0) with the object's UID and the lock mode goes
    to AUDIT_$LOG_EVENT, its flags word 1 when the request failed.  The
    callers test AUDIT_$ENABLED first.

  Status stored: none.
}

procedure file_$audit_lock(status: status_$t; in file_uid: uid_$t;
                           lock_mode: integer);
  internal;
var
  event_uid: uid_$t;
  data: file_$audit_lock_data_t;
  event_flags: pinteger;
begin
  event_uid.high := 16#40009;
  event_uid.low := 0;

  { the record }
  data.lock_mode := lock_mode;
  data.uid := file_uid;

  if status.all = status_$ok then
    event_flags := 0
  else
    event_flags := 1;

  audit_$log_event(event_uid, event_flags, status, data, 10);
end;
