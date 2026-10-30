{ dir_$do_op_get_def_prot - DIR_$DO_OP's handler for operation 16#56,
  reading a directory's default protection.

  Image addresses:
    sau2  0x00E51CF6  dir_$do_op_get_def_prot

  - As super-user, the directory opened for reading (mode 1, no rights
    asked).

  Status stored:
    dir_$read_def_prot's status: the directory was opened
    dir_$open_dir's status: it could not be
}

{ TODO(pascal) dir_$do_op_get_def_prot's open frame bytes

  The SAU2 frame has 4 bytes that no declared object explains.  The same
  open point as the other DIR frames in dir/README.md's TODO
  list. }

procedure dir_$do_op_get_def_prot(in uid: uid_$t; in acl_type: uid_$t;
                                  out prot_buf: univ acl_$prot_data_t;
                                  out acl_ret: uid_$t;
                                  out status_ret: status_$t);
var
  handle: dir_$handle_ptr_t;
begin
  acl_$enter_super;
  dir_$open_dir(uid, 1, 0, handle, status_ret);

  if status_ret.all = status_$ok then
    dir_$read_def_prot(handle^, acl_type, prot_buf, acl_ret, status_ret);

  dir_$release_handle(handle);
  acl_$exit_super;
end;
