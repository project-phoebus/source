{ DIR_$VALIDATE_ROOT_ENTRY - check one root entry against the replicated
  root, through DIR_$DO_OP, or in the old format.

  Image addresses:
    sau2  0x00E5039A  DIR_$VALIDATE_ROOT_ENTRY

  - An operation-16#50 request for NAME_$ROOT_UID; 16#F0003 or 16#E000D
    means the old kind of directory, for DIR_$OLD_VALIDATE_ROOT_ENTRY.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_validate_root_entry's status: an old-format directory
    name_$bad_leaf: a name of length 0 or over 255
}

procedure dir_$validate_root_entry(in name: univ name_$long_name_t;
                                   in name_len: pinteger;
                                   out status_ret: status_$t);
var
  response: dir_$reply_hdr_t;
  request: dir_$entry_req_t;
  received_len: integer;
  i: integer;
begin
  if (name_len = 0) or else (name_len > 255) then
    status_ret.all := name_$bad_leaf
  else begin
    request.body.path_len := name_len;
    for i := 1 to name_len do
      request.body.name[i] := name[i];

    request.hdr.op := dir_op_validate_root_entry;
    request.hdr.uid := name_$root_uid;
    request.hdr.version := dir_$op_tab[40].version;

    dir_$do_op(request, dir_$op_tab[40].base_size + request.body.path_len,
               20, response, received_len);

    if (response.status.all = file_$bad_reply_received_from_remote_node)
       or else (response.status.all = status_$naming_bad_directory) then
      dir_$old_validate_root_entry(name, name_len, status_ret)
    else
      status_ret := response.status;
  end;
end;
