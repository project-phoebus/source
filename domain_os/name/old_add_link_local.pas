{ name_$old_add_link_local - add an entry to a local old-format
  directory.

  Image addresses:
    sau2  0x00E565B8  name_$old_add_link_local

  - The root's entry is name_$old_add_entry's; another directory's is
    added under its add lock (mode 4) as an object, not replacing
    (dir_$old_add_entry).  A fragment of OLD_DIR.

  Status stored:
    name_$old_add_entry's status: the root
    dir_$old_add_entry's status: another directory was locked
    name_$unlock_dir's status: the unlock failed
    name_$lock_dir's status: the directory could not be locked
    name_$bad_leaf: the name is not a valid leaf
}

procedure name_$old_add_link_local(in dir_uid: uid_$t; rights: pinteger;
                                   in name: univ name_$long_name_t;
                                   name_len: pinteger; in file_uid: uid_$t;
                                   out status_ret: status_$t);
  internal;
var
  leaf: array[1..32] of char;
  entry: dir_$old_slot_ptr_t;
  unlock_status: status_$t;
  handle: dir_$old_dir_ptr_t;
  leaf_len: pinteger;
begin
  { the root directory }
  if dir_uid = name_$root_uid then begin
    name_$old_add_entry(dir_uid, rights, name, name_len, file_uid, 0,
                        status_ret);
    return;
  end;

  if not name_$validate_leaf(name, name_len, leaf, leaf_len) then begin
    status_ret.all := name_$bad_leaf;
    return;
  end;

  name_$lock_dir(dir_uid, handle, 4, rights, status_ret);
  if status_ret.all = status_$ok then begin
    dir_$old_add_entry(dir_uid, handle, leaf, leaf_len, 1, file_uid, false,
                       entry, status_ret);

    name_$unlock_dir(unlock_status);
    if unlock_status.all <> status_$ok then
      status_ret := unlock_status;
  end;

  acl_$exit_super;
end;
