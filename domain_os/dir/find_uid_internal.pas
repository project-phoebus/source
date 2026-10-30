{ dir_$find_uid_internal - the body of DIR_$FIND_UID and DIR_$FIND_NET:
  an entry's name by its UID, or a node's entry by the node.

  Image addresses:
    sau2  0x00E4E786  dir_$find_uid_internal (module-local)

  - An operation-16#46 request through DIR_$DO_OP; for an old-format
    directory DIR_$OLD_FIND_NET (flag true) or DIR_$OLD_FIND_UID answers.
  - With flag true the result is the extra longword; with flag false the
    name and its length.
  - DIR_$OLD_FIND_NET's answer stores no status, so status_ret is left
    as the caller had it.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    name_$leaf_truncated: the name was cut to the caller's buffer
    dir_$old_find_uid's status: an old-format directory, flag false
}

procedure dir_$find_uid_internal(in dir_uid: uid_$t; in target_uid: uid_$t;
                                 flag: boolean; name_buf_len: integer;
                                 out name_buf: univ name_$long_name_t;
                                 out name_len_ret: integer;
                                 out net_ret: integer32;
                                 var status_ret: status_$t);
  internal;
var
  response: dir_$find_uid_reply_t;
  request: dir_$find_uid_req_t;
  received_len: integer;
  i: integer;
begin
  request.hdr.op := dir_op_find_uid;
  request.hdr.uid := dir_uid;
  request.hdr.version := dir_$op_tab[35].version;
  request.body.target_uid := target_uid;
  request.body.flag := flag;

  dir_$do_op(request, dir_$op_tab[35].base_size, 16#11A, response,
             received_len);

  if (response.hdr.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.hdr.status.all = status_$naming_bad_directory)
  then begin
    { the old kind }
    if flag then
      net_ret := dir_$old_find_net(dir_uid, target_uid.low & 16#FFFFF)
    else
      dir_$old_find_uid(dir_uid, target_uid, name_buf, name_len_ret,
                        status_ret);
  end
  else begin
    status_ret := response.hdr.status;
    if status_ret.all = status_$ok then
      if flag then
        net_ret := response.find_extra
      else begin
        name_len_ret := response.name_len;
        if name_buf_len < name_len_ret then begin
          status_ret.all := name_$leaf_truncated;
          name_len_ret := name_buf_len;
        end;
        for i := 1 to name_len_ret do
          name_buf[i] := response.name[i];
      end;
  end;
end;
