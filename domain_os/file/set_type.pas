{ FILE_$SET_TYPE - set an object's type UID.

  Image addresses:
    sau2  0x00E5E176  FILE_$SET_TYPE

  - The type attribute (4) through FILE_$SET_ATTRIBUTE, asking for write
    rights (2) and no options.

  Status stored:
    file_$set_attribute's status: in either case
}

procedure file_$set_type(in file_uid: uid_$t; type_uid: uid_$t;
                         out status: status_$t);
var
  value: file_$attr_value_t;
begin
  value.uid := type_uid;

  file_$set_attribute(file_uid, 4, value, 2, 0, status);
end;
