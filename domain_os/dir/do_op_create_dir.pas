{ dir_$do_op_create_dir - DIR_$DO_OP's handler for operation 16#38,
  creating a directory and entering it in its parent.

  Image addresses:
    sau2  0x00E52576  dir_$do_op_create_dir

  - As super-user, the parent opened for writing with the create right;
    the new object gets the parent's two default ACLs.
  - A failed add lowers the default ACLs' counts again (attribute 7) and
    sets the new object's count to 0.

  Status stored:
    dir_$add_entry's status: the directory was made
    status_$ok: a server process (type 9) found a directory under the
      name already
    dir_$open_dir's or dir_$create_dir_obj's status: that step failed
}

procedure dir_$do_op_create_dir(in uid: uid_$t;
                                in name: univ name_$long_name_t;
                                name_len: integer; var result_uid: uid_$t;
                                out status_ret: status_$t);
  internal;
label
  10;
var
  value: file_$attr_value_t;
  loc: file_$obj_loc_t;
  cattr: ast_$common_attr_t;
  file_acl_uid: dir_$uid_view_t;
  dir_acl_uid: dir_$uid_view_t;
  entry: dir_$entry_ptr_t;
  status: status_$t;
  handle: dir_$handle_ptr_t;
  find_extra: integer;
  depth: integer;
  page_data: dir_$root_page_ptr_t;
  sub_type: integer;
begin
  acl_$enter_super;
  dir_$open_dir(uid, 2, 2, handle, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  { the new directory }
  page_data := dir_$map_page(handle^, 0);
  dir_acl_uid.uid := page_data^.dir_def_prot.acl_uid;
  file_acl_uid.uid := page_data^.file_def_prot.acl_uid;
  dir_$create_dir_obj(uid, page_data^, dir_acl_uid.uid, file_acl_uid.uid,
                      result_uid, status_ret);
  if status_ret.all <> status_$ok then
    goto 10;

  { its entry }
  dir_$add_entry(handle^, name, name_len, 2, 0, result_uid, 0, '',
                 status_ret);
  if status_ret.all = status_$ok then
    goto 10;

  { undo }
  value.word_val := 1;
  if dir_acl_uid.b0 <> 0 then
    ast_$set_attribute(dir_acl_uid.uid, 7, value, status);
  if file_acl_uid.b0 <> 0 then
    ast_$set_attribute(file_acl_uid.uid, 7, value, status);
  file_$set_refcnt(result_uid, 0, status);
  result_uid := uid_$nil;

  { a server's repeated create }
  if (status_ret.all = name_$already_exists) and then
     (proc1_$type[proc1_$current] = 9) then
    if dir_$find_entry(handle^, name, name_len, 0, entry, find_extra,
                       depth) then begin
      result_uid := entry^.uid;
      loc.uid := result_uid;
      loc.flags := loc.flags - [6];
      ast_$get_common_attributes(loc, 16#88, cattr, status);
      if status.all = status_$ok then begin
        sub_type := ord(cattr.sub_type);
        if (sub_type = 1) or else (sub_type = 2) then
          status_ret.all := status_$ok;
      end;
    end;

10:
  dir_$release_handle(handle);
  acl_$exit_super;
end;
