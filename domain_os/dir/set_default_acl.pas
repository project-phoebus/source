{ DIR_$SET_DEFAULT_ACL - set one of a directory's default ACLs through
  its server.

  Image addresses:
    sau2  0x00E53004  DIR_$SET_DEFAULT_ACL

  - An operation-16#4C request through DIR_$DO_OP.  For an old-format
    server a "funky" ACL UID is converted (ACL_$CONVERT_FUNKY_ACL), one
    not in the old form converted by ACL_$CONVERT_TO_9ACL, and
    DIR_$OLD_SET_DEFAULT_ACL stores it.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_set_default_acl's status: an old-format server
    acl_$convert_funky_acl's or acl_$convert_to_9acl's status: a
      conversion failed
}

procedure dir_$set_default_acl(dir_uid: uid_$t; in acl_type: uid_$t;
                               acl_uid: uid_$t;
                               out status_ret: status_$t);
var
  conv_type_uid: uid_$t;
  result_acl: dir_$uid_view_t;
  prot_data: acl_$prot_data_t;
  response: dir_$reply_hdr_t;
  request: dir_$set_default_acl_req_t;
  received_len: integer;
begin
  request.hdr.op := dir_op_set_default_acl;
  request.hdr.uid := dir_uid;
  request.hdr.version := dir_$op_tab[38].version;
  request.body.acl_type_uid := acl_type;
  request.body.acl_uid := acl_uid;

  dir_$do_op(request, dir_$op_tab[38].base_size, 20, response,
             received_len);

  if (response.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.status.all = status_$naming_bad_directory) then
  begin
    { the ACL's UID, a funky one converted }
    result_acl.uid := acl_uid;
    if (rshft(dir_$uid_view_t(acl_uid).w2 & 16#FF0, 4) & 16#E0) <> 0
    then begin
      acl_$convert_funky_acl(acl_uid, prot_data, result_acl.uid,
                             conv_type_uid, status_ret);
      if status_ret.all <> status_$ok then
        return;
    end;

    { in the old form }
    if (rshft(result_acl.w2 & 16#FF0, 4) & 16#10) <> 0 then
      result_acl.low_set := result_acl.low_set - [24]
    else begin
      acl_$convert_to_9acl(prot_data, result_acl.uid, dir_uid, acl_type,
                           result_acl.uid, status_ret);
      if status_ret.all <> status_$ok then
        return;
    end;

    dir_$old_set_default_acl(dir_uid, acl_type, result_acl.uid,
                             status_ret);
  end
  else
    status_ret := response.status;
end;
