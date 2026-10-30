{ audit_$log_mount_op - log a mount operation (a fragment of DIR).

  Image addresses:
    sau2  0x00E4BCE0  audit_$log_mount_op (module-local)

  - The given event of class 4, with a 20-byte record: the directory's
    UID, the mounted object's UID and a longword; the event's flag is 1
    when the operation failed.
  - In DIR's code segment (.TEXT), included by ../dir/dir.pas.
  - The SAU2 frame has 4 bytes no object explains (the stand-in
    unused_2c; see the TODO(pascal) in audit/log_prot_op.pas).

  Status stored: none.
}

procedure audit_$log_mount_op(audit_type: integer; status: status_$t;
                              in uid: uid_$t; in mount_uid: uid_$t;
                              extra: integer32); internal;
type
  mount_event_data_t = record
    dir_uid: uid_$t;                      { 0x00 }
    mount_uid: uid_$t;                    { 0x08 }
    extra: integer32;                     { 0x10 }
  end;
var
  ev: audit_$event_uid_t;
  data: mount_event_data_t;
  unused_2c: integer32;                   { stand-in }
  success_flag: pinteger;
begin
  ev.event_class := 4;
  ev.audit_subtype := audit_type;
  ev.reserved := 0;
  data.dir_uid := uid;
  data.mount_uid := mount_uid;
  data.extra := extra;

  if status.all = status_$ok then
    success_flag := 0
  else
    success_flag := 1;
  audit_$log_event(ev.uid, success_flag, status, data, 16#14);
end;
