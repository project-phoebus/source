{ DIR_$OLD_ROOT_ADDU - add an entry to the old-format root directory.

  Image addresses:
    sau2  0x00E569AA  DIR_$OLD_ROOT_ADDU

  - The entry is added with rights 2 and the caller's extra word.

  Status stored:
    name_$old_add_entry's status: dir_uid is the root
    status_$naming_directory_must_be_root: it is not
}

procedure dir_$old_root_addu(in dir_uid: uid_$t;
                             in name: univ name_$long_name_t;
                             in name_len: integer; in file_uid: uid_$t;
                             in extra: integer32;
                             out status_ret: status_$t);
begin
  if dir_uid <> name_$root_uid then
    status_ret.all := status_$naming_directory_must_be_root
  else
    name_$old_add_entry(dir_uid, 2, name, name_len, file_uid, extra,
                        status_ret);
end;
