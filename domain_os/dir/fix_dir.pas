{ DIR_$FIX_DIR - have a directory rebuilt (operation 16#48).

  Image addresses:
    sau2  0x00E53E84  DIR_$FIX_DIR

  - On "bad reply received from remote node" or "bad directory" the old
    protocol, DIR_$OLD_FIX_DIR, is tried.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_fix_dir's status: the old protocol was tried
}

procedure dir_$fix_dir(in dir_uid: uid_$t; out status_ret: status_$t);
var
  response: dir_$reply_hdr_t;
  request: dir_$req_hdr_t;
  received_len: integer;
begin
  request.op := dir_op_fix_dir;
  request.uid := dir_uid;
  request.version := dir_$op_tab[36].version;

  dir_$do_op(request, dir_$op_tab[36].base_size, 20, response,
             received_len);

  if (response.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.status.all = status_$naming_bad_directory) then
    dir_$old_fix_dir(dir_uid, status_ret)
  else
    status_ret := response.status;
end;
