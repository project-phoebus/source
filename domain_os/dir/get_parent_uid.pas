{ dir_$get_parent_uid - replace a directory's UID by its parent's.

  Image addresses:
    sau2  0x00E4D060  dir_$get_parent_uid

  - A directory is sub-type 1 or 2; its parent is the attributes'
    directory pointer.

  Status stored:
    ast_$get_common_attributes' status: the attributes were read
    name_$file_not_directory: the object is not a directory
    status_$naming_directory_object_not_found: the read failed with
      "object not found", or the object is remote
}

procedure dir_$get_parent_uid(in out uid: uid_$t; out status_ret: status_$t);
  internal;
var
  attrs: ast_$common_attr_t;
  loc: file_$obj_loc_t;
begin
  loc.uid := uid;
  loc.flags := loc.flags - [6];
  ast_$get_common_attributes(loc, 16#80, attrs, status_ret);

  if status_ret.all = status_$ok then
    { a directory: its parent }
    case ord(attrs.sub_type) of
      1, 2:
        uid := attrs.dirptr;
      otherwise
        status_ret.all := name_$file_not_directory;
    end
  else if (status_ret.all = file_$object_not_found) or else
          (7 in loc.flags) then
    status_ret.all := status_$naming_directory_object_not_found;
end;
