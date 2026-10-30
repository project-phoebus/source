{ DIR_$OLD_WRITE_INFOBLK - write an old-format directory's info block.

  Image addresses:
    sau2  0x00E5613C  DIR_$OLD_WRITE_INFOBLK

  - The directory is locked for writing; the lock is released and
    super-user mode left on every path.

  Status stored:
    status_$ok: the block was written
    status_$naming_illegal_directory_operation: not the old format, or a
      block longer than 40 bytes
    name_$lock_dir's status: the directory could not be locked
}

procedure dir_$old_write_infoblk(in dir_uid: uid_$t;
                                 in buf: univ dir_$old_info_t;
                                 in len: integer;
                                 out status_ret: status_$t);
var
  local_status: status_$t;
  handle: dir_$old_dir_ptr_t;
  i: integer;
begin
  name_$lock_dir(dir_uid, handle, 4, 0, status_ret);

  with handle^ do
    if status_ret.all = status_$ok then
      if (hdr.inline_slots < 19) and then (len <= 40) then begin
        info_write_len := len;
        info_read_len := len;
        for i := 1 to len do
          info[i] := buf.text[i];
        status_ret.all := status_$ok;
      end
      else
        status_ret.all := status_$naming_illegal_directory_operation;

  name_$unlock_dir(local_status);
  acl_$exit_super;
end;
