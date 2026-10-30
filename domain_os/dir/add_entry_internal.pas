{ dir_$add_entry_internal - add a name for an object to a directory,
  through DIR_$DO_OP, or in the old format.

  Image addresses:
    sau2  0x00E500B8  dir_$add_entry_internal (module-local)

  - An operation-16#2A request; 16#F0003 or 16#E000D means the old kind
    of directory, for DIR_$OLD_ROOT_ADDU when an extra longword is
    given, else DIR_$OLD_ADDU.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_root_addu's or dir_$old_addu's status: an old-format
      directory
    name_$bad_leaf: a name of length 0 or over 255
}

procedure dir_$add_entry_internal(in dir_uid: uid_$t;
                                  in name: univ name_$long_name_t;
                                  name_len: integer;
                                  in file_uid: uid_$t;
                                  extra: integer32;
                                  out status_ret: status_$t);
  internal;
var
  response: dir_$reply_hdr_t;
  request: dir_$add_entry_req_t;
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

  request.hdr.op := dir_op_addu;
  request.hdr.uid := dir_uid;
  request.hdr.version := dir_$op_tab[21].version;
  request.body.file_uid := file_uid;
  request.body.flags := extra;

  dir_$do_op(request, dir_$op_tab[21].base_size + request.body.path_len,
             20, response, received_len);

  if (response.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.status.all = status_$naming_bad_directory)
  then begin
    if extra <> 0 then
      dir_$old_root_addu(dir_uid, name, name_len, file_uid, extra,
                         status_ret)
    else
      dir_$old_addu(dir_uid, name, name_len, file_uid, status_ret);
  end
  else
    status_ret := response.status;
end;
