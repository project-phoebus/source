{ audit_$log_cname_op - log a change of name (a fragment of DIR).

  Image addresses:
    sau2  0x00E4BEC2  audit_$log_cname_op (module-local)

  - The given event of class 4, with the directory's UID, the old name
    and the new one, each terminated by a zero byte; the event's flag is
    1 when the operation failed.
  - In DIR's code segment (.TEXT), included by ../dir/dir.pas.

  Status stored: none.
}

procedure audit_$log_cname_op(audit_type: integer; status: status_$t;
                              in uid: uid_$t; name_len: pinteger;
                              new_name_len: pinteger;
                              in name: univ audit_$event_data_t;
                              in new_name: univ audit_$event_data_t);
  internal;
type
  cname_texts_t = array[0..511] of char;
  cname_texts_ptr_t = ^cname_texts_t;
  cname_event_data_t = record
    dir_uid: uid_$t;                      { 0x00 }
    names: cname_texts_t;                 { 0x08 }
  end;
var
  ev: audit_$event_uid_t;
  data: cname_event_data_t;
  len: pinteger;
  n1: linteger;
  n2: linteger;
  name_ptr: cname_texts_ptr_t;
  new_ptr: cname_texts_ptr_t;
  data_len: integer;
  success_flag: pinteger;
begin
  ev.event_class := 4;
  ev.audit_subtype := audit_type;
  ev.reserved := 0;
  data.dir_uid := uid;
  len := 0;
  if len <= name_len then
    len := name_len;
  n1 := len;
  if new_name_len = 0 then          { a no-op the image keeps }
    new_name_len := 0;
  n2 := new_name_len;
  name_ptr := addr(data.names);
  new_ptr := addr(data.names[n1 + 1]);

  if n1 <> 0 then
    os_$data_copy(name, name_ptr^, n1);
  name_ptr^[n1] := chr(0);
  if n2 <> 0 then
    os_$data_copy(new_name, new_ptr^, n2);
  new_ptr^[n2] := chr(0);
  data_len := integer32(addr(new_ptr^[n2])) - integer32(addr(data)) + 1;

  if status.all = status_$ok then
    success_flag := 0
  else
    success_flag := 1;
  audit_$log_event(ev.uid, success_flag, status, data, data_len);
end;
