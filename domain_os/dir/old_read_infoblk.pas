{ DIR_$OLD_READ_INFOBLK - read an old-format directory's info block.

  Image addresses:
    sau2  0x00E560A6  DIR_$OLD_READ_INFOBLK

  - The length handed back is clamped to max_len; the lock is released
    and super-user mode left on every path.

  Status stored:
    status_$ok: the block was read
    status_$naming_illegal_directory_operation: not the old format
    name_$lock_dir's status: the directory could not be locked
}

procedure dir_$old_read_infoblk(in dir_uid: uid_$t;
                                out buf: univ dir_$old_info_t;
                                in max_len: integer;
                                out len_out: integer;
                                out status_ret: status_$t);
var
  local_status: status_$t;
  handle: dir_$old_dir_ptr_t;
  i: integer;
begin
  name_$lock_dir(dir_uid, handle, 1, 0, status_ret);

  with handle^ do
    if status_ret.all = status_$ok then
      if hdr.inline_slots < 16#13 then begin
        len_out := info_read_len;
        if max_len < len_out then
          len_out := max_len;
        for i := 1 to len_out do
          buf.text[i] := info[i];
        status_ret.all := status_$ok;
      end
      else
        status_ret.all := status_$naming_illegal_directory_operation;

  name_$unlock_dir(local_status);
  acl_$exit_super;
end;
