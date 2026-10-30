{ FILE_$LOCK - lock an object for the calling address space.

  Image addresses:
    sau2  0x00E5EB20  FILE_$LOCK

  - FILE_$LOCK_D's shape with a slot of its own (cleared first) and the
    flags 16#24; the caller's lock_info is never touched.  With auditing
    on, the request is logged.

  Status stored:
    file_$priv_lock's status: in either case
}

procedure file_$lock(in file_uid: uid_$t; in lock_index: integer;
                     in lock_mode: integer; in rights: boolean;
                     var lock_info: integer32; out status: status_$t);
var
  slot: integer32;
  rights_out: integer;
begin
  slot := 0;

  file_$priv_lock(file_uid, proc1_$as_id, lock_index, lock_mode, rights,
                  16#24, 0, 0, 0, 0, 0, 0, slot, rights_out, status);

  if audit_$enabled then
    file_$audit_lock(status, file_uid, lock_mode);
end;
