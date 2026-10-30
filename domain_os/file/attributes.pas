{ FILE_$ATTRIBUTES - an object's attributes as an old-format VTOCE.

  Image addresses:
    sau2  0x00E5DA4C  FILE_$ATTRIBUTES

  - The object's attributes (AST_$GET_ATTRIBUTES, flags 16#21) are
    converted to the old VTOCE format into the caller's buffer
    (VTOCE_$NEW_TO_OLD) on success.

  Status stored:
    ast_$get_attributes's status: in either case
}

procedure file_$attributes(file_uid: uid_$t;
                           out attr_out: vtoce_$old_fm_t;
                           out status_ret: status_$t);
var
  desc: file_$obj_loc_t;
  buf: file_$attr_buf_t;
  status: status_$t;
begin
  desc.uid := file_uid;
  desc.flags := desc.flags - [6];
  ast_$get_attributes(desc, 16#21, buf.attrs, status);

  if status.all = status_$ok then
    vtoce_$new_to_old(buf.vtoce, true, attr_out);
  status_ret := status;
end;
