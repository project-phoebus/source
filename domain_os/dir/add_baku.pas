{ DIR_$ADD_BAKU - enter an object under a name, keeping the name's old
  object as "<name>.bak".

  Image addresses:
    sau2  0x00E50C60  DIR_$ADD_BAKU

  - An operation-16#34 request through DIR_$DO_OP (dir_$do_op_add_bak on
    the directory's node).  A remote success that names a replaced
    backup object has it flushed (AST_$COND_FLUSH).
  - "Bad reply from the remote node" or "bad directory" means an
    old-format directory, for DIR_$OLD_ADD_BAKU.
  - Only the flush clock's high half is written; its low word is
    whatever the frame held.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_add_baku's status: an old-format directory
    name_$bad_leaf: a name of length 0 or over 255
}

procedure dir_$add_baku(in dir_uid: uid_$t;
                        in name: univ name_$long_name_t;
                        in name_len: pinteger;
                        in backup_uid: uid_$t;
                        out status_ret: status_$t);
var
  response: dir_$uid_reply_t;
  request: dir_$uid_name_req_t;
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

  request.hdr.op := dir_op_add_baku;
  request.hdr.uid := dir_uid;
  request.hdr.version := dir_$op_tab[26].version;
  request.body.target_uid := backup_uid;

  dir_$do_op(request, dir_$op_tab[26].base_size + request.body.path_len,
             16#1C, response, received_len);

  status_ret := response.hdr.status;

  { a remote backup replaced: flush it }
  if (0 in response.hdr.flags) and then
     (response.hdr.status.all = status_$ok) and then
     (response.uid <> uid_$nil) then begin
    dtm.high := 0;
    ast_$cond_flush(response.uid, dtm, flush_status);
    return;
  end;

  if (response.hdr.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.hdr.status.all = status_$naming_bad_directory) then
    dir_$old_add_baku(dir_uid, name, name_len, backup_uid, status_ret);
end;
