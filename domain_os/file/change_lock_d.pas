{ FILE_$CHANGE_LOCK_D - change the mode of an object's lock held by the
  calling address space.

  Image addresses:
    sau2  0x00E5EA9E  FILE_$CHANGE_LOCK_D

  - FILE_$PRIV_LOCK makes the change for the current address space with
    the caller's side and the new mode (flags 16#44); its rights are
    dropped.  With auditing on, the request is logged.

  Status stored:
    file_$priv_lock's status: the mode was changed, or not
    file_$illegal_lock_request: a mode in file_$lock_illegal_mask
}

procedure file_$change_lock_d(in file_uid: uid_$t; in lock_index: integer;
                              in lock_mode: integer;
                              in out slot_io: integer32;
                              out status_ret: status_$t);
var
  rights_out: integer;
begin
  if lock_mode in file_$lock_illegal_mask then
    status_ret.all := file_$illegal_lock_request
  else
    file_$priv_lock(file_uid, proc1_$as_id, lock_index, lock_mode, false,
                    16#44, 0, 0, 0, 0, 0, 0, slot_io, rights_out,
                    status_ret);

  if audit_$enabled then
    file_$audit_lock(status_ret, file_uid, lock_mode);
end;
