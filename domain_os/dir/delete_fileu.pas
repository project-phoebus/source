{ DIR_$DELETE_FILEU - delete an object named in a directory.

  Image addresses:
    sau2  0x00E515BC  DIR_$DELETE_FILEU

  - An operation-16#36 request through DIR_$DO_OP; a remote success that
    names the deleted object has its pages flushed (AST_$COND_FLUSH).
  - "Bad reply from the remote node" or "bad directory" means an
    old-format directory, for DIR_$OLD_DELETE_FILEU.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_delete_fileu's status: an old-format directory
    name_$bad_leaf: a name of length 0 or over 255
}

procedure dir_$delete_fileu(in dir_uid: uid_$t;
                            in name: univ name_$long_name_t;
                            in name_len: pinteger;
                            out status_ret: status_$t;
                            in check_del_right: boolean;
                            in no_lock: boolean);
var
  response: dir_$uid_reply_t;
  request: dir_$delete_file_req_t;
  dtm: time_$clock_t;
  flush_status: status_$t;
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

  request.hdr.op := dir_op_delete_fileu;
  request.hdr.uid := dir_uid;
  request.hdr.version := dir_$op_tab[27].version;
  request.body.flag0 := check_del_right;
  request.body.flag1 := no_lock;

  dir_$do_op(request, dir_$op_tab[27].base_size + request.body.path_len,
             16#1C, response, received_len);

  status_ret := response.hdr.status;

  { a remote object deleted: flush it }
  if (0 in response.hdr.flags) and then
     (response.hdr.status.all = status_$ok) and then
     (response.uid <> uid_$nil) then begin
    dtm.high := 0;
    ast_$cond_flush(response.uid, dtm, flush_status);
    return;
  end;

  if (response.hdr.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.hdr.status.all = status_$naming_bad_directory) then
    dir_$old_delete_fileu(dir_uid, name, name_len, status_ret,
                          check_del_right, no_lock);
end;
