{ DIR_$OLD_DELETE_FILEU - delete a file from an old-format directory.

  Image addresses:
    sau2  0x00E5716E  DIR_$OLD_DELETE_FILEU

  - Links not allowed; the dropped entry's UID is dropped.

  Status stored:
    name_$old_delete_entryu's status: always
}

procedure dir_$old_delete_fileu(in dir_uid: uid_$t;
                                in name: univ name_$long_name_t;
                                in name_len: pinteger;
                                out status_ret: status_$t;
                                in check_del_right: boolean;
                                in no_lock: boolean);
var
  dropped_uid: uid_$t;
begin
  name_$old_delete_entryu(dir_uid, name, name_len, check_del_right, no_lock,
                          false, dropped_uid, status_ret);
end;
