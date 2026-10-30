{ AUDIT_$LOG_EVENT - log an event for the current process.

  Image addresses:
    sau2  0x00E70DF6  AUDIT_$LOG_EVENT

  - When logging is on, the event goes to AUDIT_$LOG_EVENT_S with the
    current process's SID block, if that could be fetched.

  Status stored: none.
}

procedure audit_$log_event(in event_uid: uid_$t; in event_flags: pinteger;
                           in status: status_$t;
                           in data: univ audit_$event_data_t;
                           in data_len: pinteger);
var
  sid: acl_sid_block_t;
  local_status: status_$t;
begin
  if audit_$enabled then begin
    acl_$get_pid_sid(proc1_$current, sid, local_status);
    if local_status.all = status_$ok then
      audit_$log_event_s(event_uid, event_flags, sid, status, data,
                         data_len);
  end;
end;
