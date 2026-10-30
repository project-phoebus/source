{ FILE_$SET_DTM_F - set an object's time of last modification.

  Image addresses:
    sau2  0x00E5E1EE  FILE_$SET_DTM_F

  - The time given (attribute 23, rights 8), or with the flag the
    current clock's high part (attribute 26, rights 10), through
    FILE_$SET_ATTRIBUTE.
  - An old-format object ("incompatible request") gets the time rounded
    up to a whole high part as attribute 9 (AST_$SET_ATTRIBUTE).

  Status stored:
    file_$set_attribute's status: the time was set, or not
    ast_$set_attribute's status: an old-format object
}

procedure file_$set_dtm_f(in file_uid: uid_$t; in flags: boolean;
                          in time_value: time_$clock_t;
                          out status_ret: status_$t);
var
  value: file_$attr_value_t;
  rights: integer;
  attr_id: integer;
begin
  value.clock := time_value;

  if flags then begin
    rights := 10;
    value.clock.high := time_$current_clockh;
    value.clock.low := 0;
    attr_id := 26;
  end
  else begin
    rights := 8;
    attr_id := 23;
  end;

  file_$set_attribute(file_uid, attr_id, value, rights, -1, status_ret);

  if status_ret.all = status_$ast_incompatible_request then begin
    if value.clock.low <> 0 then
      value.clock.high := value.clock.high + 1;
    ast_$set_attribute(file_uid, 9, value, status_ret);
  end;
end;
