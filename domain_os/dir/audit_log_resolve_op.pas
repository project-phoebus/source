{ audit_$log_resolve_op - log a pathname resolution (DIR's sixth event
  logger).

  Image addresses:
    sau2  0x00E4BF92  audit_$log_resolve_op (module-local)

  - Event 16#21 of class 4: the resolved UID and the pathname, its length
    kept and a zero byte after it; the flag is 1 when the operation
    failed.

  Status stored: none.
}

procedure audit_$log_resolve_op(in pname: univ audit_$event_data_t;
                                path_len: pinteger;
                                in result_uid: uid_$t;
                                status: status_$t); internal;
type
  resolve_event_data_t = record
    result_uid: uid_$t;                   { 0x00 }
    path: array[0..1023] of char;         { 0x08 }
  end;
var
  ev: audit_$event_uid_t;
  data: resolve_event_data_t;
  len: pinteger;
  n: linteger;
  data_len: integer;
  success_flag: pinteger;
begin
  ev.event_class := 4;
  ev.audit_subtype := 16#21;
  ev.reserved := 0;
  len := 0;
  if len <= path_len then
    len := path_len;
  n := len;
  data.result_uid := result_uid;

  if n <> 0 then
    os_$data_copy(pname, data.path, n);
  data.path[n] := chr(0);
  data_len := integer32(addr(data.path[n])) - integer32(addr(data)) + 1;

  if status.all = status_$ok then
    success_flag := 0
  else
    success_flag := 1;
  audit_$log_event(ev.uid, success_flag, status, data, data_len);
end;
