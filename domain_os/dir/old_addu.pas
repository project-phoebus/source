{ DIR_$OLD_ADDU - add an object entry to an old-format directory.

  Image addresses:
    sau2  0x00E5694A  DIR_$OLD_ADDU

  - A plain entry, not a hard link (name_$old_add_link).

  Status stored:
    name_$old_add_link's status: always
}

procedure dir_$old_addu(in dir_uid: uid_$t; in name: univ name_$long_name_t;
                        in name_len: integer; in file_uid: uid_$t;
                        out status_ret: status_$t);
begin
  name_$old_add_link(dir_uid, name, name_len, file_uid, false, status_ret);
end;
