{ FILE_$LOCK_D - lock an object for the calling address space, keeping
  the caller's per-process slot.

  Image addresses:
    sau2  0x00E5EA2A  FILE_$LOCK_D

  - FILE_$PRIV_LOCK locks it for the current address space with the
    caller's side, mode and local-only byte, the flags 4 and the
    caller's slot; its rights are dropped.  With auditing on, the
    request is logged.

  Status stored:
    file_$priv_lock's status: in either case
}

procedure file_$lock_d(in file_uid: uid_$t; in lock_index: integer;
                       in lock_mode: integer; in rights: boolean;
                       in out slot_io: integer32;
                       out status_ret: status_$t);
var
  rights_out: integer;
begin
  file_$priv_lock(file_uid, proc1_$as_id, lock_index, lock_mode, rights,
                  4, 0, 0, 0, 0, 0, 0, slot_io, rights_out, status_ret);

  if audit_$enabled then
    file_$audit_lock(status_ret, file_uid, lock_mode);
end;
