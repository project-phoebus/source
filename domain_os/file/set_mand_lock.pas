{ FILE_$SET_MAND_LOCK - set or clear an object's mandatory-lock flag.

  Image addresses:
    sau2  0x00E5DC6A  FILE_$SET_MAND_LOCK

  - The mandatory-lock attribute (25) through FILE_$SET_ATTRIBUTE,
    asking for the rights 8 and no options.

  Status stored:
    file_$set_attribute's status: in either case
}

procedure file_$set_mand_lock(in file_uid: uid_$t; in flag: boolean;
                              out status_ret: status_$t);
var
  value: file_$attr_value_t;
begin
  value.flag := flag;

  file_$set_attribute(file_uid, 25, value, 8, 0, status_ret);
end;
