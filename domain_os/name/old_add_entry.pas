{ name_$old_add_entry - add an object entry to an old-format directory.

  Image addresses:
    sau2  0x00E56682  name_$old_add_entry

  - Under the directory's add lock (mode 4, the caller's rights) the
    entry is added, replacing one, with the caller's extra word
    (dir_$old_add_entry_ext); on success its hint goes to HINT_$ADDI.
  - Super-user mode, which name_$lock_dir entered, is left.  A fragment
    of OLD_DIR.

  Status stored:
    dir_$old_add_entry_ext's status: the directory was locked
    name_$unlock_dir's status: the unlock failed
    name_$lock_dir's status: the directory could not be locked
    name_$bad_leaf: the name is not a valid leaf
}

procedure name_$old_add_entry(in dir_uid: uid_$t; rights: pinteger;
                              in name: univ name_$long_name_t;
                              name_len: pinteger; in file_uid: uid_$t;
                              flags: integer32; out status_ret: status_$t);
  internal;
var
  location: hint_$addr_t;
  parsed: array[1..32] of char;
  entry: dir_$old_slot_ptr_t;
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
    dir_$old_add_entry_ext(dir_uid, handle, parsed, parsed_len, 1, file_uid,
                           flags, true, entry, status_ret);

    if status_ret.all = status_$ok then begin
      location.flags := flags;
      location.node_id := file_uid.low & 16#FFFFF;
      hint_$addi(file_uid, location);
    end;

    name_$unlock_dir(unlock_status);
    if unlock_status.all <> status_$ok then
      status_ret := unlock_status;
  end;

  acl_$exit_super;
end;
