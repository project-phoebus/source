{ audit_$log_link_op - log a link operation (a fragment of DIR).

  Image addresses:
    sau2  0x00E4BD48  audit_$log_link_op (module-local)

  - The given event of class 4, with the directory's UID, the link's
    name and its target (each length clamped at 0, each terminated by a
    zero byte); the event's flag is 1 when the operation failed.
  - In DIR's code segment (.TEXT), included by ../dir/dir.pas.

  Status stored: none.
}

procedure audit_$log_link_op(audit_type: integer; status: status_$t;
                             in uid: uid_$t; name_len: integer;
                             in name: univ audit_$event_data_t;
                             target_len: integer;
                             in target_data: univ audit_$event_data_t);
  internal;
type
  link_texts_t = array[0..1279] of char;
  link_texts_ptr_t = ^link_texts_t;
  link_event_data_t = record
    dir_uid: uid_$t;                      { 0x00 }
    names: link_texts_t;                  { 0x08 }
  end;
var
  ev: audit_$event_uid_t;
  data: link_event_data_t;
  len: integer;
  n1: linteger;
  n2: linteger;
  target_ptr: link_texts_ptr_t;
  data_len: integer;
  success_flag: pinteger;
begin
  ev.event_class := 4;
  ev.audit_subtype := audit_type;
  ev.reserved := 0;
  len := 0;
  if len < name_len then
    len := name_len;
  n1 := len;
  if target_len < 0 then
    target_len := 0;
  n2 := target_len;
  data.dir_uid := uid;
  target_ptr := addr(data.names[n1 + 1]);

  if n1 <> 0 then
    os_$data_copy(name, data.names, n1);
  data.names[n1] := chr(0);
  if n2 <> 0 then
    os_$data_copy(target_data, target_ptr^, n2);
  target_ptr^[n2] := chr(0);
  data_len := integer32(addr(target_ptr^[n2])) - integer32(addr(data)) + 1;

  if status.all = status_$ok then
    success_flag := 0
  else
    success_flag := 1;
  audit_$log_event(ev.uid, success_flag, status, data, data_len);
end;
