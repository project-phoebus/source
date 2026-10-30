{ DIR_$OLD_ADD_HARD_LINKU - add a hard link to an old-format directory.

  Image addresses:
    sau2  0x00E5697A  DIR_$OLD_ADD_HARD_LINKU

  Status stored:
    name_$old_add_link's status: always
}

procedure dir_$old_add_hard_linku(in dir_uid: uid_$t;
                                  in name: univ name_$long_name_t;
                                  in name_len: pinteger;
                                  in target_uid: uid_$t;
                                  out status_ret: status_$t);
begin
  name_$old_add_link(dir_uid, name, name_len, target_uid, true, status_ret);
end;
