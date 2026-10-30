{ dir_$old_add_entry_ext - add an entry and store its extra longword.

  Image addresses:
    sau2  0x00E55406  dir_$old_add_entry_ext (module-local)

  - The extra longword goes into the new slot when the status's low word
    is 0.

  Status stored:
    dir_$old_add_entry's status: always
}

procedure dir_$old_add_entry_ext(in dir_uid: uid_$t;
                                 dir: dir_$old_dir_ptr_t;
                                 in new_name: univ name_$long_name_t;
                                 new_name_len: pinteger;
                                 entry_type: integer;
                                 in uid_data: uid_$t; extra: integer32;
                                 replace_flag: boolean;
                                 out entry_ret: dir_$old_slot_ptr_t;
                                 out status_ret: status_$t);
  internal;
begin
  dir_$old_add_entry(dir_uid, dir, new_name, new_name_len, entry_type,
                     uid_data, replace_flag, entry_ret, status_ret);

  if status_ret.code = 0 then
    entry_ret^.extra := extra;
end;
