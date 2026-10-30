{ DIR_$SET_DEF_PROTECTION - set a directory's default protection for an
  ACL type.

  Image addresses:
    sau2  0x00E520A6  DIR_$SET_DEF_PROTECTION

  - An operation-16#54 request through DIR_$DO_OP; for an old-format
    directory the protection is converted by ACL_$CONVERT_TO_9ACL and
    set with DIR_$OLD_SET_DEFAULT_ACL.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_set_default_acl's status: an old-format directory
    acl_$convert_to_9acl's status: the conversion failed
}

procedure dir_$set_def_protection(in dir_uid: uid_$t; in acl_type: uid_$t;
                                  in prot: acl_$prot_data_t;
                                  in def_acl: uid_$t;
                                  out status_ret: status_$t);
var
  old_acl: uid_$t;
  response: dir_$reply_hdr_t;
  request: dir_$set_def_prot_req_t;
  received_len: integer;
begin
  request.hdr.op := dir_op_set_def_protection;
  request.hdr.uid := dir_uid;
  request.hdr.version := dir_$op_tab[42].version;
  request.acl_type_uid := acl_type;
  request.prot := prot;
  request.acl_uid := def_acl;

  dir_$do_op(request, dir_$op_tab[42].base_size, 20, response,
             received_len);

  if (response.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.status.all = status_$naming_bad_directory) then
  begin
    acl_$convert_to_9acl(prot, def_acl, dir_uid, acl_type, old_acl,
                         status_ret);
    if status_ret.all = status_$ok then
      dir_$old_set_default_acl(dir_uid, acl_type, old_acl, status_ret);
  end
  else
    status_ret := response.status;
end;
