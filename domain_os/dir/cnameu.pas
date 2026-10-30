{ DIR_$CNAMEU - rename an entry of a directory.

  Image addresses:
    sau2  0x00E51B68  DIR_$CNAMEU

  - An operation-16#32 request, the new name right after the old one,
    through DIR_$DO_OP; "bad reply from the remote node" or "bad
    directory" means an old-format directory, for DIR_$OLD_CNAMEU.

  Status stored:
    the reply's status: DIR_$DO_OP answered
    dir_$old_cnameu's status: an old-format directory
    name_$bad_leaf: either name of length 0 or over 255
}

procedure dir_$cnameu(in dir_uid: uid_$t;
                      in old_name: univ name_$long_name_t;
                      in old_name_len: pinteger;
                      in new_name: univ name_$long_name_t;
                      in new_name_len: pinteger;
                      out status_ret: status_$t);
var
  response: dir_$reply_hdr_t;
  request: dir_$cname_req_t;
  received_len: integer;
  i: integer;
begin
  if (old_name_len = 0) or else (new_name_len = 0) or else
     (old_name_len > 255) or else (new_name_len > 255) then begin
    status_ret.all := name_$bad_leaf;
    return;
  end;

  { the old name }
  request.body.old_len := old_name_len;
  for i := 1 to request.body.old_len do
    request.body.name[i] := old_name[i];

  { the new name after it }
  request.body.new_len := new_name_len;
  for i := 1 to request.body.new_len do
    request.text[i + dir_$op_tab[25].base_size + request.body.old_len] :=
      new_name[i];

  request.hdr.op := dir_op_cnameu;
  request.hdr.uid := dir_uid;
  request.hdr.version := dir_$op_tab[25].version;

  dir_$do_op(request, dir_$op_tab[25].base_size + request.body.old_len +
             request.body.new_len, 20, response, received_len);

  if (response.status.all = file_$bad_reply_received_from_remote_node)
     or else (response.status.all = status_$naming_bad_directory) then
    dir_$old_cnameu(dir_uid, old_name, old_name_len, new_name,
                    new_name_len, status_ret)
  else
    status_ret := response.status;
end;
