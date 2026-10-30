{ FILE_$SET_TROUBLE - mark an object as in trouble.

  Image addresses:
    sau2  0x00E5DC42  FILE_$SET_TROUBLE

  - The trouble attribute (2) is set to true through
    FILE_$SET_ATTRIBUTE, asking for no rights and all options.  The
    second argument is not read.

  Status stored:
    file_$set_attribute's status: in either case
}

procedure file_$set_trouble(in file_uid: uid_$t; in unused: integer32;
                            out status_ret: status_$t);
var
  value: file_$attr_value_t;
begin
  value.flag := true;

  file_$set_attribute(file_uid, 2, value, 0, -1, status_ret);
end;
