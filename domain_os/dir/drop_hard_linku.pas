{ DIR_$DROP_HARD_LINKU - drop a name (a hard link) from a directory.

  Image addresses:
    sau2  0x00E516FC  DIR_$DROP_HARD_LINKU

  - An operation-16#2E request through DIR_$DO_OP; a remote success that
    names the dropped object has its pages flushed (AST_$COND_FLUSH).
  - "Bad reply from the remote node" or "bad directory" means an
    old-format directory, for DIR_$OLD_DROP_HARD_LINKU.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_drop_hard_linku's status: an old-format directory
    name_$bad_leaf: a name of length 0 or over 255
}

procedure dir_$drop_hard_linku(in dir_uid: uid_$t;
                               in name: univ name_$long_name_t;
                               in name_len: pinteger;
                               in flags: dir_$drop_flags_t;
                               out status_ret: status_$t);
var
  response: dir_$uid_reply_t;
  request: dir_$word_name_req_t;
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

  request.hdr.op := dir_op_drop_hard_linku;
  request.hdr.uid := dir_uid;
  request.hdr.version := dir_$op_tab[23].version;
  request.body.flags := flags;

  dir_$do_op(request, dir_$op_tab[23].base_size + request.body.path_len,
             16#1C, response, received_len);

  status_ret := response.hdr.status;

  { a remote object dropped: flush it }
  if (0 in response.hdr.flags) and then
     (response.hdr.status.all = status_$ok) and then
     (response.uid <> uid_$nil) then begin
    dtm.high := 0;
    ast_$cond_flush(response.uid, dtm, flush_status);
    return;
  end;

  if (response.hdr.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.hdr.status.all = status_$naming_bad_directory) then
    dir_$old_drop_hard_linku(dir_uid, name, name_len, flags, status_ret);
end;
