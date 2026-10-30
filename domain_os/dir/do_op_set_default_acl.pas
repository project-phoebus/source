{ dir_$do_op_set_default_acl - DIR_$DO_OP's handler for operation 16#4C,
  setting one of a local directory's default ACLs.

  Image addresses:
    sau2  0x00E52FA6  dir_$do_op_set_default_acl

  - As super-user, the directory opened for writing (mode 2, rights 8);
    the page is forced out.

  Status stored:
    dir_$set_default_acl_internal's status: the directory was opened
    dir_$open_dir's status: it could not be
}

procedure dir_$do_op_set_default_acl(in dir_uid: uid_$t;
                                     in acl_type: uid_$t;
                                     in src_acl_uid: uid_$t;
                                     out status_ret: status_$t);
var
  handle: dir_$handle_ptr_t;
begin
  acl_$enter_super;
  dir_$open_dir(dir_uid, 2, 8, handle, status_ret);

  if status_ret.all = status_$ok then
    dir_$set_default_acl_internal(handle^, acl_type, src_acl_uid, true,
                                  status_ret);

  dir_$release_handle(handle);
  acl_$exit_super;
end;
