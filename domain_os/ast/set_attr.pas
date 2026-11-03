{ AST_$SET_ATTR - set one attribute of an object, with the caller's time
  and wait flag.

  Image addresses:
    sau2  0x00E05400  AST_$SET_ATTR
    sau4  0x0F8057AC  AST_$SET_ATTR
    sau9  0x3C4066AA  AST_$SET_ATTR

  - As AST_$SET_ATTRIBUTE, with the caller's flag as `wait' and the
    caller's time.

  Status stored:
    ast_$set_attribute_internal's status: the attribute was set, or not
    acl_$get_exsid's status: the SID record could not be had
}

procedure ast_$set_attr(uid: uid_$t; attr_id: integer;
                        in value: file_$attr_value_t; flags: boolean;
                        in clock: time_$clock_t; out status: status_$t);
var
  exsid: acl_$exsid_t;
  local_status: status_$t;
begin
  if attr_id = ast_attr_merge_acl then begin
    acl_$get_exsid(exsid, status);
    if status.all <> status_$ok then
      return;
  end;

  proc1_$inhibit_begin;
  ast_$set_attribute_internal(uid, attr_id, addr(value), flags, addr(exsid),
                              clock, local_status);
  proc1_$inhibit_end;
  status := local_status;
end;
