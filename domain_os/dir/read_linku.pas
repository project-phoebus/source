{ DIR_$READ_LINKU - read a soft link's text.

  Image addresses:
    sau2  0x00E4D6C0  DIR_$READ_LINKU

  - An operation-16#3E request (the buffer's length and address) through
    DIR_$DO_OP, whose reply gives the UID and the text's length; "bad
    reply from the remote node" or "bad directory" means an old-format
    directory, for DIR_$OLD_READ_LINKU.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_read_linku's status: an old-format directory
    name_$bad_leaf: a name of length 0 or over 255
    status_$naming_bad_buffer_size: a buffer length of 0 or less
}

procedure dir_$read_linku(in dir_uid: uid_$t;
                          in name: univ name_$long_name_t;
                          in name_len: pinteger;
                          in buf_len: integer;
                          var target: univ name_$long_pname_t;
                          out target_len: integer;
                          out target_uid: uid_$t;
                          out status_ret: status_$t);
var
  response: dir_$link_reply_t;
  request: dir_$link_req_t;
  received_len: integer;
  i: integer;
begin
  if (name_len = 0) or else (name_len > 255) then begin
    status_ret.all := name_$bad_leaf;
    return;
  end;

  request.body.target_len := buf_len;
  if request.body.target_len <= 0 then begin
    status_ret.all := status_$naming_bad_buffer_size;
    return;
  end;

  request.body.path_len := name_len;
  for i := 1 to name_len do
    request.body.name[i] := name[i];

  request.hdr.op := dir_op_read_linku;
  request.hdr.uid := dir_uid;
  request.hdr.version := dir_$op_tab[31].version;
  request.body.target_ptr := addr(target);

  dir_$do_op(request, dir_$op_tab[31].base_size + request.body.path_len,
             16#1E, response, received_len);

  status_ret := response.hdr.status;
  target_uid := response.entry;
  target_len := response.len;

  if (status_ret.all = file_$bad_reply_received_from_remote_node) or else
     (status_ret.all = status_$naming_bad_directory) then
    dir_$old_read_linku(dir_uid, name, name_len, target, target_len,
                        target_uid, status_ret);
end;
