{ FILE_$SET_MGR_ATTR - set an object's type manager attribute.

  Image addresses:
    sau2  0x00E5E39A  FILE_$SET_MGR_ATTR

  - For version 0 of the request, the 8-byte manager attribute becomes
    attribute 14 through FILE_$SET_ATTRIBUTE, asking for write rights
    (2) and all options.

  Status stored:
    file_$set_attribute's status: version 0
    file_$invalid_arg: any other version
}

procedure file_$set_mgr_attr(in file_uid: uid_$t; in mgr_attr: uid_$t;
                             in version: integer;
                             out status_ret: status_$t);
var
  value: file_$attr_value_t;
  attr_id: integer;
begin
  if version = 0 then
    attr_id := 14
  else begin
    status_ret.all := file_$invalid_arg;
    return;
  end;

  value.uid := mgr_attr;

  file_$set_attribute(file_uid, attr_id, value, 2, -1, status_ret);
end;
