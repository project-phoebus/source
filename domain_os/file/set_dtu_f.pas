{ FILE_$SET_DTU_F - set an object's time of last use.

  Image addresses:
    sau2  0x00E5E2C2  FILE_$SET_DTU_F

  - The time given becomes attribute 24 through FILE_$SET_ATTRIBUTE,
    asking for no rights and all options.  An old-format object gets it
    rounded up to a whole high part as attribute 10.

  Status stored:
    file_$set_attribute's status: the time was set, or not
    ast_$set_attribute's status: an old-format object
}

procedure file_$set_dtu_f(in file_uid: uid_$t; in time_value: time_$clock_t;
                          out status_ret: status_$t);
var
  value: file_$attr_value_t;
begin
  value.clock := time_value;

  file_$set_attribute(file_uid, 24, value, 0, -1, status_ret);

  if status_ret.all = status_$ast_incompatible_request then begin
    if value.clock.low <> 0 then
      value.clock.high := value.clock.high + 1;
    ast_$set_attribute(file_uid, 10, value, status_ret);
  end;
end;
