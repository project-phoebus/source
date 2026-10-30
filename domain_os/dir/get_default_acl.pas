{ DIR_$GET_DEFAULT_ACL - a directory's default ACL of a kind.

  Image addresses:
    sau2  0x00E531C8  DIR_$GET_DEFAULT_ACL

  - An operation-16#4E request through DIR_$DO_OP; "bad reply from the
    remote node" or "bad directory" means an old-format directory, for
    DIR_$OLD_GET_DEFAULT_ACL.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_get_default_acl's status: an old-format directory
}

procedure dir_$get_default_acl(in dir_uid: uid_$t; in acl_type: uid_$t;
                               out acl_ret: uid_$t;
                               out status_ret: status_$t);
var
  response: dir_$uid_reply_t;
  request: dir_$uid_req_t;
  received_len: integer;
begin
  request.hdr.op := dir_op_get_default_acl;
  request.hdr.uid := dir_uid;
  request.hdr.version := dir_$op_tab[39].version;
  request.acl_type := acl_type;

  dir_$do_op(request, dir_$op_tab[39].base_size, 16#1C, response,
             received_len);

  if (response.hdr.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.hdr.status.all = status_$naming_bad_directory) then
    dir_$old_get_default_acl(dir_uid, acl_type, acl_ret, status_ret)
  else begin
    acl_ret := response.uid;
    status_ret := response.hdr.status;
  end;
end;
