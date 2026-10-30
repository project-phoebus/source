{ dir_$do_op_set_acl - DIR_$DO_OP's handler for operation 16#4A, setting
  a local directory's ACL.

  Image addresses:
    sau2  0x00E52BC2  dir_$do_op_set_acl

  - As super-user, the directory opened for writing (mode 2, no rights);
    a "funky" ACL UID is converted (ACL_$CONVERT_FUNKY_ACL) and set as
    protection type 4.
  - The operation goes to the audit trail when auditing is on.

  Status stored:
    file_$set_prot's status: the ACL was converted
    status_$acl_unimplemented_call: any other kind of ACL UID
    dir_$open_dir's or acl_$convert_funky_acl's status: that step failed
}

procedure dir_$do_op_set_acl(in uid: uid_$t; in acl_uid: uid_$t;
                             out status_ret: status_$t);
label
  10;
var
  target_uid: uid_$t;
  prot_info: uid_$t;
  acl_data: acl_$prot_data_t;
  handle: dir_$handle_ptr_t;
begin
  acl_$enter_super;
  dir_$open_dir(uid, 2, 0, handle, status_ret);

  if status_ret.all = status_$ok then begin
    if (rshft(dir_$uid_view_t(acl_uid).w2 & 16#FF0, 4) & 16#E0) <> 0
    then begin
      acl_$convert_funky_acl(acl_uid, acl_data, prot_info, target_uid,
                             status_ret);
      if status_ret.all <> status_$ok then
        goto 10;
    end
    else begin
      status_ret.all := status_$acl_unimplemented_call;
      goto 10;
    end;
    file_$set_prot(uid, 4, acl_data, prot_info, status_ret);
  end;

10:
  dir_$release_handle(handle);
  acl_$exit_super;

  if audit_$enabled then
    audit_$log_prot_op(status_ret, uid, acl_data, acl_$dirin_acl,
                       prot_info, 4);
end;
