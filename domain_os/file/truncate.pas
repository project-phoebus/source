{ FILE_$TRUNCATE - truncate an object.

  Image addresses:
    sau2  0x00E73FCA  FILE_$TRUNCATE

  - FILE_$TRUNCATE_D with the context 0; FILE_$SET_LEN's code but for
    the displacements.

  Status stored:
    file_$truncate_d's status: in either case
}

[section(proc2_create_pro, proc2_create_dat)]
procedure file_$truncate(in file_uid: uid_$t; in new_size: integer32;
                         out status: status_$t);
begin
  file_$truncate_d(file_uid, new_size, 0, status);
end;
