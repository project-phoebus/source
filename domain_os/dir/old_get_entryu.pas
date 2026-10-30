{ DIR_$OLD_GET_ENTRYU - look a name up in an old-format directory.

  Image addresses:
    sau2  0x00E58056  DIR_$OLD_GET_ENTRYU

  - The root goes to name_$old_get_root_entry (which falls back on the
    replicated root), any other directory to
    name_$old_get_entry_nonroot.

  Status stored:
    the callee's status: always
}

procedure dir_$old_get_entryu(dir_uid: uid_$t;
                              in name: univ name_$long_name_t;
                              in name_len: pinteger;
                              out entry: dir_$old_entry_t;
                              out status_ret: status_$t);
begin
  if dir_uid = name_$root_uid then
    name_$old_get_root_entry(dir_uid, name, name_len, entry, status_ret)
  else
    name_$old_get_entry_nonroot(dir_uid, name, name_len, entry,
                                status_ret);
end;
