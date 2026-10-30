{ DIR_$OLD_FIND_UID - the name an old-format directory gives a UID.

  Image addresses:
    sau2  0x00E558D6  DIR_$OLD_FIND_UID

  - Under a read lock (mode 1) the slots are searched and the name
    mapped back to the caller's case (UNMAP_CASE).  Not found in the
    root, the replicated root is asked (REM_NAME_$FIND_UID) and its
    answer entered in the local root.
  - Super-user mode, which name_$lock_dir enters, is left on every path.

  Status stored:
    name_$unlock_dir's status: the UID was found
    rem_name_$find_uid's status: the root's replicated root was asked
    dir_$old_find_uid_slot's status (name_$not_found): not found
    name_$lock_dir's status: the directory could not be locked
}

procedure dir_$old_find_uid(in dir_uid: uid_$t; in target_uid: uid_$t;
                            out name_buf: univ name_$long_name_t;
                            out name_len_ret: integer;
                            out status_ret: status_$t);
var
  entry: rem_name_$dir_entry_t;
  add_status: status_$t;
  unlock_status: status_$t;
  handle: dir_$old_dir_ptr_t;
  truncated: boolean;
begin
  name_$lock_dir(dir_uid, handle, 1, 0, status_ret);
  if status_ret.all = status_$ok then begin
    dir_$old_find_uid_slot(handle, target_uid, entry.name, entry.name_len,
                           status_ret);
    name_$unlock_dir(unlock_status);

    if status_ret.all = status_$ok then begin
      unmap_case(entry.name, entry.name_len, name_buf, 16#20,
                 name_len_ret, truncated);
      status_ret := unlock_status;
    end
    else if (status_ret.all = name_$not_found) and then
            (dir_uid = name_$root_uid) then begin
      rem_name_$find_uid(dir_uid, target_uid, entry, status_ret);
      if status_ret.all = status_$ok then begin
        unmap_case(entry.name, entry.name_len, name_buf, 16#20,
                   name_len_ret, truncated);
        name_$old_add_entry(dir_uid, 0, name_buf, name_len_ret, entry.uid,
                            entry.extra, add_status);
      end;
    end;
  end;

  acl_$exit_super;
end;
