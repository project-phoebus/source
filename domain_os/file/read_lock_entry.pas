{ FILE_$READ_LOCK_ENTRY - the next lock of a volume or address space, as
  the caller's 26 bytes.

  Image addresses:
    sau2  0x00E608EC  FILE_$READ_LOCK_ENTRY

  - FILE_$READ_LOCK_ENTRYI reads the next lock record (and moves the
    caller's index on); on success its first 26 bytes go to the caller.

  Status stored:
    file_$read_lock_entryi's status: in either case
}

procedure file_$read_lock_entry(file_uid: uid_$t; in out index: pinteger;
                                out info_out: file_$lock_user_t;
                                out status_ret: status_$t);
var
  buf: file_$lock_info_t;
begin
  file_$read_lock_entryi(file_uid, index, buf, status_ret);

  if status_ret.all = status_$ok then
    info_out := buf.user;
end;
