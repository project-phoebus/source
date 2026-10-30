{ FILE_$GET_ATTRIBUTES - an object's attributes in the 0x90-byte form.

  Image addresses:
    sau2  0x00E5D984  FILE_$GET_ATTRIBUTES

  - The request word's bits choose AST_$GET_ATTRIBUTES' flags as in
    FILE_$GET_ATTR_INFO.  The record, the location and the status go
    back to the caller whatever the status.

  Status stored:
    ast_$get_attributes's status: the attributes were read, or not
    file_$invalid_arg: a request with none of the three bits, or a
      buffer size other than 144 (checked before the call)
}

procedure file_$get_attributes(in file_uid: uid_$t; in req: integer;
                               in size: integer;
                               in out loc: file_$obj_loc_t;
                               out attrs: file_$attributes_t;
                               out status: status_$t);
var
  desc: file_$obj_loc_t;
  buf: file_$attributes_t;
  ast_status: status_$t;
  unused_b8: integer32;                   { TODO }
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

  desc.uid := file_uid;
  desc.flags := desc.flags - [6];
  if size <> 144 then begin
    status.all := file_$invalid_arg;
    return;
  end;

  ast_$get_attributes(desc, flags, buf, ast_status);
  attrs := buf;
  loc := desc;
  status := ast_status;
end;
