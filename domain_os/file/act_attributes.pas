{ FILE_$ACT_ATTRIBUTES - an object's attributes as an old-format VTOCE,
  without the remote refresh.

  Image addresses:
    sau2  0x00E5DAB0  FILE_$ACT_ATTRIBUTES

  - FILE_$ATTRIBUTES (file/attributes.pas) with AST_$GET_ATTRIBUTES'
    flags 1 instead of 16#21.

  Status stored:
    ast_$get_attributes's status: in either case
}

procedure file_$act_attributes(file_uid: uid_$t;
                               out attr_out: vtoce_$old_fm_t;
                               out status_ret: status_$t);
var
  desc: file_$obj_loc_t;
  buf: file_$attr_buf_t;
  status: status_$t;
begin
  desc.uid := file_uid;
  desc.flags := desc.flags - [6];
  ast_$get_attributes(desc, 1, buf.attrs, status);

  if status.all = status_$ok then
    vtoce_$new_to_old(buf.vtoce, true, attr_out);
  status_ret := status;
end;
