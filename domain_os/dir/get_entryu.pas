{ DIR_$GET_ENTRYU - look an entry up by name in a directory.

  Image addresses:
    sau2  0x00E4D500  DIR_$GET_ENTRYU
    sau2  0x00E4D460  dir_$get_entryu_via_do_op (nested)

  - The nested dir_$get_entryu_via_do_op sends an operation-16#44
    request and copies the entry's type, UID and longword out of the
    reply.
  - "Bad reply from the remote node" or "bad directory" means an
    old-format directory, for DIR_$OLD_GET_ENTRYU.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_get_entryu's status: an old-format directory
    name_$bad_leaf: a name of length 0 or over 255
}

procedure dir_$get_entryu(dir_uid: uid_$t;
                          in name: univ name_$long_name_t;
                          in name_len: pinteger;
                          out entry: dir_$old_entry_t;
                          out status_ret: status_$t);

  procedure dir_$get_entryu_via_do_op(out status_ret: status_$t);
  var
    response: dir_$entry_reply_t;
    request: dir_$entry_req_t;
    received_len: integer;
    i: integer;
  begin
    request.body.path_len := name_len;
    for i := 1 to request.body.path_len do
      request.body.name[i] := name[i];

    request.hdr.op := dir_op_get_entryu_op;
    request.hdr.uid := dir_uid;
    request.hdr.version := dir_$op_tab[34].version;

    dir_$do_op(request, dir_$op_tab[34].base_size + request.body.path_len,
               16#22, response, received_len);

    status_ret := response.hdr.status;
    if status_ret.all = status_$ok then begin
      entry.entry_type := response.len;
      entry.uid := response.entry;
      entry.extra := response.extra;
    end;
  end;

begin
  if (name_len = 0) or else (name_len > 255) then
    status_ret.all := name_$bad_leaf
  else begin
    dir_$get_entryu_via_do_op(status_ret);

    if (status_ret.all = file_$bad_reply_received_from_remote_node) or else
       (status_ret.all = status_$naming_bad_directory) then
      dir_$old_get_entryu(dir_uid, name, name_len, entry, status_ret);
  end;
end;
