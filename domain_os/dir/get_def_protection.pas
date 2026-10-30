{ DIR_$GET_DEF_PROTECTION - read a directory's default protection for
  an ACL type.

  Image addresses:
    sau2  0x00E51D54  DIR_$GET_DEF_PROTECTION

  - An operation-16#56 request through DIR_$DO_OP; for an old-format
    directory the default ACL (DIR_$OLD_GET_DEFAULT_ACL) is converted by
    ACL_$CONVERT_FROM_9ACL.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    acl_$convert_from_9acl's status: an old-format directory
    dir_$old_get_default_acl's status: its ACL could not be read
}

procedure dir_$get_def_protection(in dir_uid: uid_$t; in acl_type: uid_$t;
                                  var prot_buf: acl_$prot_data_t;
                                  out prot_uid: uid_$t;
                                  out status_ret: status_$t);
var
  old_acl: uid_$t;
  response: dir_$def_prot_reply_t;
  request: dir_$uid_req_t;
  received_len: integer;
begin
  request.hdr.op := dir_op_get_def_protection;
  request.hdr.uid := dir_uid;
  request.hdr.version := dir_$op_tab[43].version;
  request.acl_type := acl_type;

  dir_$do_op(request, dir_$op_tab[43].base_size, 16#48, response,
             received_len);

  if (response.hdr.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.hdr.status.all = status_$naming_bad_directory) then
  begin
    dir_$old_get_default_acl(dir_uid, acl_type, old_acl, status_ret);
    if status_ret.all = status_$ok then
      acl_$convert_from_9acl(old_acl, acl_type, prot_buf, prot_uid,
                             status_ret);
  end
  else begin
    prot_buf := response.prot;
    prot_uid := response.acl_uid;
    status_ret := response.hdr.status;
  end;
end;
