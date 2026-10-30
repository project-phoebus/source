{ dir_$do_op_set_def_prot - DIR_$DO_OP's handler for operation 16#54,
  setting a directory's default protection.

  Image addresses:
    sau2  0x00E52044  dir_$do_op_set_def_prot

  - As super-user, the directory opened for writing (mode 2, right 8);
    the page is forced out.

  Status stored:
    dir_$write_def_prot's status: the directory was opened
    dir_$open_dir's status: it could not be
}

procedure dir_$do_op_set_def_prot(in dir_uid: uid_$t; in acl_type: uid_$t;
                                  in prot_data: univ acl_$prot_data_t;
                                  in src_acl_uid: uid_$t;
                                  out status_ret: status_$t);
var
  handle: dir_$handle_ptr_t;
begin
  acl_$enter_super;
  dir_$open_dir(dir_uid, 2, 8, handle, status_ret);

  if status_ret.all = status_$ok then
    dir_$write_def_prot(handle^, acl_type, prot_data, src_acl_uid, true,
                        status_ret);

  dir_$release_handle(handle);
  acl_$exit_super;
end;
