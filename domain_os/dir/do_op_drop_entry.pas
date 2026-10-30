{ dir_$do_op_drop_entry - DIR_$DO_OP's drop operations: remove a named
  entry.

  Image addresses:
    sau2  0x00E511DA  dir_$do_op_drop_entry

  - As super-user, the directory opened for writing with the rights
    asked for; the caller's entry type is the operation type.

  Status stored:
    dir_$remove_entry's status: the directory was opened
    status_$ok: a server process (type 9) found the name gone (a retry
      after success)
    dir_$open_dir's status: it could not be
}

procedure dir_$do_op_drop_entry(in uid: uid_$t; rights: integer;
                                in name: univ name_$long_name_t;
                                name_len: integer; entry_type: integer;
                                out result_uid: uid_$t;
                                out status_ret: status_$t);
  internal;
var
  handle: dir_$handle_ptr_t;
begin
  acl_$enter_super;

  dir_$open_dir(uid, 2, rights, handle, status_ret);

  if status_ret.all = status_$ok then
    dir_$remove_entry(handle^, name, name_len, entry_type, result_uid,
                      status_ret);

  { a server's retry }
  if (status_ret.all = name_$not_found) and then
     (proc1_$type[proc1_$current] = 9) then
    status_ret.all := status_$ok;

  dir_$release_handle(handle);
  acl_$exit_super;
end;
