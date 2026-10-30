{ DIR_$CREATE_DIRU - create a directory named in a directory.

  Image addresses:
    sau2  0x00E529EE  DIR_$CREATE_DIRU

  - An operation-16#38 request through DIR_$DO_OP, whose reply gives the
    new directory's UID; "bad reply from the remote node" or "bad
    directory" means an old-format directory, for DIR_$OLD_CREATE_DIRU.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_create_diru's status: an old-format directory
    name_$bad_leaf: a name of length 0 or over 255
}

procedure dir_$create_diru(in parent_uid: uid_$t;
                           in name: univ name_$long_name_t;
                           in name_len: pinteger;
                           var new_dir_uid: uid_$t;
                           out status_ret: status_$t);
var
  response: dir_$uid_reply_t;
  request: dir_$entry_req_t;
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

  request.hdr.op := dir_op_create_diru;
  request.hdr.uid := parent_uid;
  request.hdr.version := dir_$op_tab[28].version;

  dir_$do_op(request, dir_$op_tab[28].base_size + request.body.path_len,
             16#1C, response, received_len);

  if (response.hdr.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.hdr.status.all = status_$naming_bad_directory) then
    dir_$old_create_diru(parent_uid, name, name_len, new_dir_uid,
                         status_ret)
  else begin
    status_ret := response.hdr.status;
    new_dir_uid := response.uid;
  end;
end;
