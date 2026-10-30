{ DIR_$DROP_LINKU - drop a soft link from a directory.

  Image addresses:
    sau2  0x00E517F6  DIR_$DROP_LINKU

  - An operation-16#40 request through DIR_$DO_OP; "bad reply from the
    remote node" or "bad directory" means an old-format directory, for
    DIR_$OLD_DROP_LINKU.  The reply also gives the caller its UID.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_drop_linku's status: an old-format directory
    name_$bad_leaf: a name of length 0 or over 255
}

procedure dir_$drop_linku(in dir_uid: uid_$t;
                          in name: univ name_$long_name_t;
                          in name_len: pinteger;
                          out target_uid: uid_$t;
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

  request.hdr.op := dir_op_drop_linku;
  request.hdr.uid := dir_uid;
  request.hdr.version := dir_$op_tab[32].version;

  dir_$do_op(request, dir_$op_tab[32].base_size + request.body.path_len,
             16#1C, response, received_len);

  if (response.hdr.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.hdr.status.all = status_$naming_bad_directory) then
    dir_$old_drop_linku(dir_uid, name, name_len, target_uid, status_ret)
  else begin
    target_uid := response.uid;
    status_ret := response.hdr.status;
  end;
end;
