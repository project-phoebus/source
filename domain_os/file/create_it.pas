{ FILE_$CREATE_IT - create an object of a given type, types 0, 4 and 5
  only.

  Image addresses:
    sau2  0x00E5D79E  FILE_$CREATE_IT

  - The others go to FILE_$PRIV_CREATE with the caller's type UID,
    directory and size, no flags and no owner information; its result is
    the result.

  Status stored:
    file_$priv_create's status: the type was 0, 4 or 5
    file_$invalid_arg: any other type
}

function file_$create_it(in file_type: integer; in type_uid: uid_$t;
                         in dir_uid: uid_$t; in size: integer32;
                         var file_uid_ret: uid_$t;
                         out status_ret: status_$t): boolean;
begin
  if not ((file_type = 5) or (file_type = 4) or (file_type = 0)) then
    status_ret.all := file_$invalid_arg
  else
    file_$create_it := file_$priv_create(file_type, type_uid, dir_uid,
                                         file_uid_ret, size, 0, nil,
                                         status_ret);
end;
