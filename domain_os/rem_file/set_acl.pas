{ REM_FILE_$SET_ACL - set an object's ACL on the object's home node.

  Image addresses:
    sau2  0x00E62AA8  REM_FILE_$SET_ACL

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$set_acl(var addr_info: integer32;
                            in file_uid: uid_$t;
                            in acl_uid: uid_$t;
                            in acl_header: acl_$prot_data_t;
                            in sid_data: acl_sid_block_t;
                            in perm_data: acl_$proj_uids_t;
                            flags: integer;
                            extra_flags: integer;
                            out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_set_acl;
  request.chk_flags := rem_file_acl_req_flags;
  request.chk_sids := sid_data;
  request.chk_perm := perm_data;
  request.chk_flags2 := flags;
  request.uid := file_uid;
  request.chk_acl_uid := acl_uid;
  request.chk_header := acl_header;
  request.chk_extra_flags := extra_flags;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 170, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);
end;
