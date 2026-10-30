{ FILE_$SET_LEN - set an object's length.

  Image addresses:
    sau2  0x00E73F90  FILE_$SET_LEN

  - FILE_$TRUNCATE_D with the context 0.

  Status stored:
    file_$truncate_d's status: in either case
}

[section(proc2_create_pro, proc2_create_dat)]
procedure file_$set_len(in file_uid: uid_$t; in new_length: integer32;
                        out status: status_$t);
begin
  file_$truncate_d(file_uid, new_length, 0, status);
end;
