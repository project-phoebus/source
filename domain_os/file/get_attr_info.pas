{ FILE_$GET_ATTR_INFO - an object's attributes in the 0x7A-byte form.

  Image addresses:
    sau2  0x00E5D7F4  FILE_$GET_ATTR_INFO

  - The request word's bits choose AST_$GET_ATTRIBUTES' flags: bit 0
    gives 1, bit 2 16#21, bit 1 1 if the object is locked, else 16#21.
  - On success the location goes back, and the 0x7A-byte record is
    built from the 0x90-byte one, field by field.

  Status stored:
    ast_$get_attributes's status: the attributes were read, or not
    file_$invalid_arg: a request with none of the three bits, or a
      buffer size other than 122
}

procedure file_$get_attr_info(in file_uid: uid_$t; in req: integer;
                              in size: integer;
                              in out loc: file_$obj_loc_t;
                              out info: file_$attr_info_t;
                              out status: status_$t);
var
  desc: file_$obj_loc_t;
  attrs: file_$attributes_t;
  ast_status: status_$t;
  flags: integer;
  lock_info: boolean;
begin
  { the attribute request's flags }
  if (req & 1) <> 0 then
    flags := 1
  else if (req & 4) <> 0 then
    flags := 16#21
  else if (req & 2) <> 0 then begin
    if file_$delete_int(loc.uid, 0, lock_info, ast_status) then
      flags := 1
    else
      flags := 16#21;
  end
  else begin
    status.all := file_$invalid_arg;
    return;
  end;

  { the attributes }
  desc.uid := file_uid;
  desc.flags := desc.flags - [6];
  ast_$get_attributes(desc, flags, attrs, ast_status);
  status := ast_status;
  if ast_status.all <> status_$ok then
    return;

  loc := desc;
  if size <> 122 then begin
    status.all := file_$invalid_arg;
    return;
  end;

  { the 0x7A-byte record }
  info.word_00 := attrs.word_00 & 16#FF1F06;
  info.bits.ext_7 := attrs.ext.ext_7;
  info.id_04 := attrs.id_04;
  info.lengths := attrs.lengths;
  info.dtu := attrs.dtu;
  info.clock_2c := attrs.clock_24;
  info.devno := attrs.devno;
  info.dta := attrs.dta;
  info.link_count := attrs.link_count;
  info.id_3e := attrs.id_78;
  info.acl_ids := attrs.acl_ids;
  info.acl_flags := attrs.ext.acl_flags;
  info.unknown_6e := attrs.unknown_68;
  info.bits.ext_5 := attrs.ext.ext_5;
  info.bits.ext_4 := attrs.ext.ext_4;
end;
