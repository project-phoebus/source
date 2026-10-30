{ FILE_$MK_IMMUTABLE - make an object immutable.

  Image addresses:
    sau2  0x00E5DBC0  FILE_$MK_IMMUTABLE

  - The immutable attribute (1) is set to true through
    FILE_$SET_ATTRIBUTE, asking for the rights 2 and all options.

  Status stored:
    file_$set_attribute's status: in either case
}

procedure file_$mk_immutable(in file_uid: uid_$t; out status_ret: status_$t);
var
  value: file_$attr_value_t;
begin
  value.flag := true;

  file_$set_attribute(file_uid, 1, value, 2, -1, status_ret);
end;
