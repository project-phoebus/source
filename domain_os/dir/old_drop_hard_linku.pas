{ DIR_$OLD_DROP_HARD_LINKU - remove an entry from an old-format
  directory.

  Image addresses:
    sau2  0x00E56ACA  DIR_$OLD_DROP_HARD_LINKU

  - The rights check is flags member 0; no-lock and link on; the
    object's UID is dropped.

  Status stored:
    name_$old_delete_entryu's status: always
}

procedure dir_$old_drop_hard_linku(in dir_uid: uid_$t;
                                   in name: univ name_$long_name_t;
                                   in name_len: pinteger;
                                   in flags: dir_$drop_flags_t;
                                   out status_ret: status_$t);
var
  dropped_uid: uid_$t;
begin
  name_$old_delete_entryu(dir_uid, name, name_len, 0 in flags, true, true,
                          dropped_uid, status_ret);
end;
