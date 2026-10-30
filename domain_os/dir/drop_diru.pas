{ DIR_$DROP_DIRU - delete a directory named in a directory.

  Image addresses:
    sau2  0x00E52AB4  DIR_$DROP_DIRU

  - An operation-16#3A request through DIR_$DO_OP; "bad reply from the
    remote node" or "bad directory" means an old-format directory, for
    DIR_$OLD_DROP_DIRU.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_drop_diru's status: an old-format directory
    name_$bad_leaf: a name of length 0 or over 255
}

procedure dir_$drop_diru(in parent_uid: uid_$t;
                         in name: univ name_$long_name_t;
                         in name_len: pinteger;
                         out status_ret: status_$t);
var
  response: dir_$reply_hdr_t;
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

  request.hdr.op := dir_op_drop_diru;
  request.hdr.uid := parent_uid;
  request.hdr.version := dir_$op_tab[29].version;

  dir_$do_op(request, dir_$op_tab[29].base_size + request.body.path_len,
             20, response, received_len);

  if (response.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.status.all = status_$naming_bad_directory) then
    dir_$old_drop_diru(parent_uid, name, name_len, status_ret)
  else
    status_ret := response.status;
end;
