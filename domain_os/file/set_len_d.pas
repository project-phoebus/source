{ FILE_$SET_LEN_D - set an object's length, with a lock context.

  Image addresses:
    sau2  0x00E73FB0  FILE_$SET_LEN_D

  - FILE_$TRUNCATE_D with the caller's arguments.

  Status stored:
    file_$truncate_d's status: in either case
}

[section(proc2_create_pro, proc2_create_dat)]
procedure file_$set_len_d(in file_uid: uid_$t; in new_length: integer32;
                          in domain_ctx: linteger;
                          out status_ret: status_$t);
begin
  file_$truncate_d(file_uid, new_length, domain_ctx, status_ret);
end;
