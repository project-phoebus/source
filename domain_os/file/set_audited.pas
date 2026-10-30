{ FILE_$SET_AUDITED - set an object's audit flags, for an audit
  administrator.

  Image addresses:
    sau2  0x00E5DBE8  FILE_$SET_AUDITED

  - The two booleans become members 0 and 1 of a word set; for an audit
    administrator the set is stored as the audited attribute (13)
    through FILE_$SET_ATTRIBUTE, asking for no rights and all options.

  Status stored:
    file_$set_attribute's status: the caller is an administrator
    audit_$administrator's status: otherwise
}

procedure file_$set_audited(in file_uid: uid_$t; in audit_flag: boolean;
                            in audit_flag2: boolean;
                            out status_ret: status_$t);
var
  value: file_$attr_value_t;
begin
  value.audit := [];
  if audit_flag then
    value.audit := [0];
  if audit_flag2 then
    value.audit := value.audit + [1];

  if audit_$administrator(status_ret) then
    file_$set_attribute(file_uid, 13, value, 0, -1, status_ret);
end;
