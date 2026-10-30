{ name_$old_drop_entry - remove an entry from an old-format directory.

  Image addresses:
    sau2  0x00E56A04  name_$old_drop_entry

  - Under the directory's lock (mode 4, the caller's rights) the entry
    is unlinked (dir_$old_unlink_entry, operation 1), the removed
    object's UID handed back.  Super-user mode is left.  A fragment of
    OLD_DIR.

  Status stored:
    name_$unlock_dir's status: the unlink's code word was 0
    dir_$old_unlink_entry's status: the unlink failed
    name_$lock_dir's status: the directory could not be locked
    name_$bad_leaf: the name is not a valid leaf
}

procedure name_$old_drop_entry(in dir_uid: uid_$t;
                               in name: univ name_$long_name_t;
                               name_len: pinteger; rights: pinteger;
                               out uid_ret: uid_$t;
                               out status_ret: status_$t);
  internal;
var
  parsed: array[1..32] of char;
  unlock_status: status_$t;
  handle: dir_$old_dir_ptr_t;
  parsed_len: pinteger;
begin
  if not name_$validate_leaf(name, name_len, parsed, parsed_len) then begin
    status_ret.all := name_$bad_leaf;
    return;
  end;

  name_$lock_dir(dir_uid, handle, 4, rights, status_ret);
  if status_ret.all = status_$ok then begin
    dir_$old_unlink_entry(dir_uid, handle, parsed, parsed_len, 1, uid_ret,
                          status_ret);

    name_$unlock_dir(unlock_status);
    if status_ret.code = 0 then
      status_ret := unlock_status;
  end;

  acl_$exit_super;
end;
