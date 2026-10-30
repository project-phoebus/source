{ FILE_$SET_DEVNO - set an object's device number.

  Image addresses:
    sau2  0x00E5E362  FILE_$SET_DEVNO

  - The device attribute (22) through FILE_$SET_ATTRIBUTE, asking for
    control rights (8) and all options.

  Status stored:
    file_$set_attribute's status: in either case
}

procedure file_$set_devno(in file_uid: uid_$t; in devno: integer;
                          out status_ret: status_$t);
var
  value: file_$attr_value_t;
begin
  value.word_val := devno;

  file_$set_attribute(file_uid, 22, value, 8, -1, status_ret);
end;
