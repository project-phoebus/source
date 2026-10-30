{ DIR_$ADDU - add a name for an object to a directory.

  Image addresses:
    sau2  0x00E501A0  DIR_$ADDU

  - dir_$add_entry_internal with no extra longword (0): DIR_$DO_OP, or
    OLD_DIR's DIR_$OLD_ADDU.

  Status stored:
    dir_$add_entry_internal's status: always
}

procedure dir_$addu(in dir_uid: uid_$t; in name: univ name_$long_name_t;
                    in name_len: integer; in file_uid: uid_$t;
                    out status_ret: status_$t);
begin
  dir_$add_entry_internal(dir_uid, name, name_len, file_uid, 0,
                          status_ret);
end;
