{ DIR_$ADD_HARD_LINKU - add a hard link, a second name for an object, to
  a directory.

  Image addresses:
    sau2  0x00E505CA  DIR_$ADD_HARD_LINKU

  - An operation-16#2C request through DIR_$DO_OP; "bad reply from the
    remote node" or "bad directory" means an old-format directory, for
    DIR_$OLD_ADD_HARD_LINKU.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_add_hard_linku's status: an old-format directory
    name_$bad_leaf: a name of length 0 or over 255
}

procedure dir_$add_hard_linku(in dir_uid: uid_$t;
                              in name: univ name_$long_name_t;
                              in name_len: pinteger;
                              in target_uid: uid_$t;
                              out status_ret: status_$t);
var
  response: dir_$reply_hdr_t;
  request: dir_$uid_name_req_t;
  received_len: integer;
  i: integer;
begin
  if (name_len = 0) or else (name_len > 255) then begin
    status_ret.all := name_$bad_leaf;
    return;
  end;

  request.body.path_len := name_len;
  for i := 1 to request.body.path_len do
    request.body.name[i] := name[i];

  request.hdr.op := dir_op_add_hard_linku;
  request.hdr.uid := dir_uid;
  request.hdr.version := dir_$op_tab[22].version;
  request.body.target_uid := target_uid;

  dir_$do_op(request, dir_$op_tab[22].base_size + request.body.path_len,
             20, response, received_len);

  if (response.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.status.all = status_$naming_bad_directory) then
    dir_$old_add_hard_linku(dir_uid, name, name_len, target_uid,
                            status_ret)
  else
    status_ret := response.status;
end;
