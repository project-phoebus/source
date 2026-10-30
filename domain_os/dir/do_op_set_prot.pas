{ dir_$do_op_set_prot - DIR_$DO_OP's handler for operation 16#52, setting
  an object's protection in a local directory.

  Image addresses:
    sau2  0x00E5216A  dir_$do_op_set_prot

  - As super-user, the object opened as a directory (mode 2, no rights
    asked); a "funky" ACL UID is converted (ACL_$CONVERT_FUNKY_ACL).
  - FILE_$SET_PROT runs out of super-user mode.

  Status stored:
    file_$set_prot's status: the protection was set, or failed
    dir_$open_dir's or acl_$convert_funky_acl's status: that step failed
}

procedure dir_$do_op_set_prot(in uid: uid_$t;
                              in prot_data: univ acl_$prot_data_t;
                              in acl_uid: uid_$t; prot_type: integer;
                              out status_ret: status_$t);
label
  10;
var
  acl_type: uid_$t;
  def_acl: uid_$t;
  prot: acl_$prot_data_t;
  handle: dir_$handle_ptr_t;
begin
  acl_$enter_super;
  dir_$open_dir(uid, 2, 0, handle, status_ret);

  if status_ret.all = status_$ok then begin
    if (rshft(dir_$uid_view_t(acl_uid).w2 & 16#FF0, 4) & 16#E0) <> 0
    then begin
      acl_$convert_funky_acl(acl_uid, prot, def_acl, acl_type, status_ret);
      if status_ret.all <> status_$ok then
        goto 10;
    end
    else begin
      prot := prot_data;
      def_acl := acl_uid;
    end;
    acl_$exit_super;
    file_$set_prot(uid, prot_type, prot, def_acl, status_ret);
    acl_$enter_super;
  end;

10:
  dir_$release_handle(handle);
  acl_$exit_super;
end;
