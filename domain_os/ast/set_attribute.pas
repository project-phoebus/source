{ AST_$SET_ATTRIBUTE - set one attribute of an object, now.

  Image addresses:
    sau2  0x00E05380  AST_$SET_ATTRIBUTE
    sau9  0x3C40662A  AST_$SET_ATTRIBUTE

  - For the ACL merge (attribute 16#14) the caller's extended SID record
    is fetched first.
  - With the time read and process switching inhibited, the attribute is
    set by ast_$set_attribute_internal, `wait' true.

  Status stored:
    ast_$set_attribute_internal's status: the attribute was set, or not
    acl_$get_exsid's status: the SID record could not be had
}

procedure ast_$set_attribute(uid: uid_$t; attr_id: integer;
                             in value: file_$attr_value_t;
                             out status: status_$t);
var
  exsid: acl_$exsid_t;
  clock: time_$clock_t;
  local_status: status_$t;
begin
  if attr_id = ast_attr_merge_acl then begin
    acl_$get_exsid(exsid, status);
    if status.all <> status_$ok then
      return;
  end;

  time_$clock(clock);
  proc1_$inhibit_begin;
  ast_$set_attribute_internal(uid, attr_id, addr(value), true, addr(exsid),
                              clock, local_status);
  proc1_$inhibit_end;
  status := local_status;
end;
