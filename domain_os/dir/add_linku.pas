{ DIR_$ADD_LINKU - add a soft link, a name whose entry holds a pathname,
  to a directory.

  Image addresses:
    sau2  0x00E5068E  DIR_$ADD_LINKU

  - An operation-16#3C request through DIR_$DO_OP; it carries the text's
    address, not the text (DIR_$READ_LINKU's form).
  - "Bad reply from the remote node" or "bad directory" means an
    old-format directory, for DIR_$OLD_ADD_LINKU.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_add_linku's status: an old-format directory
    name_$bad_leaf: a name of length 0 or over 255
    name_$bad_link: a text of length 0 or over 1023, or a request over
      1280 bytes with the name
}

procedure dir_$add_linku(in dir_uid: uid_$t;
                         in name: univ name_$long_name_t;
                         in name_len: pinteger;
                         in target: univ name_$long_pname_t;
                         in target_len: pinteger;
                         out status_ret: status_$t);
var
  response: dir_$reply_hdr_t;
  request: dir_$link_req_t;
  received_len: integer;
  i: integer;
begin
  if (name_len = 0) or else (name_len > 255) then begin
    status_ret.all := name_$bad_leaf;
    return;
  end;

  if (target_len = 0) or else (target_len > 1023) or else
     (name_len + target_len + dir_$op_tab[30].base_size + 16#8E > 16#500)
  then begin
    status_ret.all := name_$bad_link;
    return;
  end;

  request.body.path_len := name_len;
  for i := 1 to request.body.path_len do
    request.body.name[i] := name[i];

  request.body.target_len := target_len;
  request.body.target_ptr := addr(target);
  request.hdr.op := dir_op_add_linku;
  request.hdr.uid := dir_uid;
  request.hdr.version := dir_$op_tab[30].version;

  dir_$do_op(request, dir_$op_tab[30].base_size + request.body.path_len,
             20, response, received_len);

  if (response.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.status.all = status_$naming_bad_directory) then
    dir_$old_add_linku(dir_uid, name, name_len, target, target_len,
                       status_ret)
  else
    status_ret := response.status;
end;
