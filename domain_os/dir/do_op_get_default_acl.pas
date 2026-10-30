{ dir_$do_op_get_default_acl - DIR_$DO_OP's handler for operation 16#4E,
  reading a directory's default ACL.

  Image addresses:
    sau2  0x00E53128  dir_$do_op_get_default_acl

  - As super-user, the directory opened for reading (mode 1, no rights
    asked).
  - The ACL's UID is the directory's own with member 25 (ACL_$DIR_ACL)
    or 26 (ACL_$FILE_ACL) of its low half set.

  Status stored:
    status_$ok: the directory was opened, for a directory or file ACL
    status_$naming_bad_type: any other ACL type
    dir_$open_dir's status: the directory could not be opened
}

procedure dir_$do_op_get_default_acl(in dir_uid: uid_$t;
                                     in acl_type: uid_$t;
                                     out acl_ret: dir_$uid_view_t;
                                     out status_ret: status_$t);
var
  handle: dir_$handle_ptr_t;
begin
  acl_$enter_super;
  dir_$open_dir(dir_uid, 1, 0, handle, status_ret);

  with handle^ do
    if status_ret.all = status_$ok then begin
      status_ret.all := status_$ok;
      if acl_type = acl_$dir_acl then begin
        acl_ret.uid := uid;
        acl_ret.low_set := acl_ret.low_set + [25];
      end
      else if acl_type = acl_$file_acl then begin
        acl_ret.uid := uid;
        acl_ret.low_set := acl_ret.low_set + [26];
      end
      else
        status_ret.all := status_$naming_bad_type;
    end;

  dir_$release_handle(handle);
  acl_$exit_super;
end;
