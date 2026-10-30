{ file_$audit_set_prot - log an audit event for a protection change.

  Image addresses:
    sau2  0x00E5DC96  file_$audit_set_prot

  - The event (16#4000A, 0) with the protection data, the object's UID,
    the second UID and the protection kind goes to AUDIT_$LOG_EVENT, its
    flags word 1 when the change failed.  The callers test
    AUDIT_$ENABLED first.

  Status stored: none.
}

procedure file_$audit_set_prot(in file_uid: uid_$t;
                               in acl_data: acl_$prot_data_t;
                               in prot_info: uid_$t; prot_type: integer;
                               status: status_$t);
  internal;
var
  event_uid: uid_$t;
  data: file_$audit_set_prot_data_t;
  event_flags: pinteger;
begin
  event_uid.high := 16#4000A;
  event_uid.low := 0;

  { the record }
  data.acl_data := acl_data;
  data.file_uid := file_uid;
  data.prot_info := prot_info;
  data.prot_type := prot_type;

  if status.all = status_$ok then
    event_flags := 0
  else
    event_flags := 1;

  audit_$log_event(event_uid, event_flags, status, data, 62);
end;
