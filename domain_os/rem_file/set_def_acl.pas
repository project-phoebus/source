{ REM_FILE_$SET_DEF_ACL - set a directory's default ACL on its home node.

  Image addresses:
    sau2  0x00E622EE  REM_FILE_$SET_DEF_ACL

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$set_def_acl(in addr_info: integer32;
                                in dir_uid: uid_$t; in acl_type: uid_$t;
                                in acl_uid: uid_$t;
                                out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_set_def_acl;
  request.uid := dir_uid;
  request.def_acl_type := acl_type;
  request.def_acl_uid := acl_uid;
  request.def_version := rem_file_req_version;
  request.def_force := true;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 32, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);
end;
