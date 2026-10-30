{ FILE_$READ_LOCK_ENTRYU - the lock record of an object, for a user.

  Image addresses:
    sau2  0x00E6042E  FILE_$READ_LOCK_ENTRYU

  - FILE_$READ_LOCK_ENTRYUI's full lock record; on success its first 26
    bytes go to the caller.

  Status stored:
    file_$read_lock_entryui's status: in either case
}

procedure file_$read_lock_entryu(in file_uid: uid_$t;
                                 out info_out: file_$lock_user_t;
                                 out status_ret: status_$t);
var
  buf: file_$lock_info_t;
begin
  file_$read_lock_entryui(file_uid, buf, status_ret);

  if status_ret.all = status_$ok then
    info_out := buf.user;
end;
