{ DIR_$OLD_DROP_LINKU - remove a soft link from an old-format directory.

  Image addresses:
    sau2  0x00E57924  DIR_$OLD_DROP_LINKU

  - The super-user mode name_$lock_dir entered is left (not on the bad
    leaf's early return).

  Status stored:
    name_$unlock_dir's status: the unlink worked
    dir_$old_unlink_entry's status: it did not
    name_$lock_dir's status: the directory could not be locked
    name_$bad_leaf: the name is not a valid leaf
}

procedure dir_$old_drop_linku(in dir_uid: uid_$t;
                              in name: univ name_$long_name_t;
                              in name_len: pinteger;
                              out target_uid: uid_$t;
                              out status_ret: status_$t);
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

  name_$lock_dir(dir_uid, handle, 4, 2, status_ret);
  if status_ret.all = status_$ok then begin
    dir_$old_unlink_entry(dir_uid, handle, parsed, parsed_len, 3, target_uid,
                          status_ret);

    name_$unlock_dir(unlock_status);
    if status_ret.code = 0 then
      status_ret := unlock_status;
  end;

  acl_$exit_super;
end;
