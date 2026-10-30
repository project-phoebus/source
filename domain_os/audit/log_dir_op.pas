{ audit_$log_dir_op - log a directory operation (a fragment of DIR).

  Image addresses:
    sau2  0x00E4BE16  audit_$log_dir_op (module-local)

  - The given event of class 4, with the directory's UID, the file's UID
    and the name (its length clamped at 0, terminated by a zero byte);
    the event's flag is 1 when the operation failed.
  - In DIR's code segment (.TEXT), included by ../dir/dir.pas.

  Status stored: none.
}

procedure audit_$log_dir_op(audit_type: integer; status: status_$t;
                            in dir_uid: uid_$t; in file_uid: uid_$t;
                            name_len: integer;
                            in name: univ audit_$event_data_t); internal;
type
  dir_event_data_t = record
    dir_uid: uid_$t;                      { 0x00 }
    file_uid: uid_$t;                     { 0x08 }
    name: array[0..255] of char;          { 0x10 }
  end;
var
  ev: audit_$event_uid_t;
  data: dir_event_data_t;
  len: integer;
  n: linteger;
  data_len: integer;
  success_flag: pinteger;
begin
  ev.event_class := 4;
  ev.audit_subtype := audit_type;
  ev.reserved := 0;
  len := 0;
  if len < name_len then
    len := name_len;
  n := len;
  data.dir_uid := dir_uid;
  data.file_uid := file_uid;

  if n <> 0 then
    os_$data_copy(name, data.name, n);
  data.name[n] := chr(0);
  data_len := integer32(addr(data.name[n])) - integer32(addr(data)) + 1;

  if status.all = status_$ok then
    success_flag := 0
  else
    success_flag := 1;
  audit_$log_event(ev.uid, success_flag, status, data, data_len);
end;
