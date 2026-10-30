{ FILE_$SET_DIRPTR - set an object's parent directory pointer.

  Image addresses:
    sau2  0x00E5E1B2  FILE_$SET_DIRPTR

  - The directory pointer (attribute 5) through FILE_$SET_ATTRIBUTE,
    asking for no rights and all options.

  Status stored:
    file_$set_attribute's status: in either case
}

procedure file_$set_dirptr(in uid: uid_$t; parent_uid: uid_$t;
                           out status_ret: status_$t);
var
  value: file_$attr_value_t;
begin
  value.uid := parent_uid;

  file_$set_attribute(uid, 5, value, 0, -1, status_ret);
end;
