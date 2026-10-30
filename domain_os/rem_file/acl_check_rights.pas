{ REM_FILE_$ACL_CHECK_RIGHTS - evaluate a caller's rights to an object on
  the object's home node.

  Image addresses:
    sau2  0x00E629E8  REM_FILE_$ACL_CHECK_RIGHTS

  - result_out is the reply's longword.

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$acl_check_rights(var addr_info: integer32;
                                     in sid_data: acl_sid_block_t;
                                     in perm_data: acl_$proj_uids_t;
                                     in file_uid: uid_$t;
                                     check_flag: boolean;
                                     access_mask: integer32;
                                     flags: integer;
                                     flag2: boolean;
                                     flag3: boolean;
                                     out result_out: integer32;
                                     out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_acl_check_rights;
  request.chk_flags := rem_file_acl_req_flags;
  request.chk_sids := sid_data;
  request.chk_perm := perm_data;
  request.chk_check := check_flag;
  request.chk_flag2 := flag2;
  request.chk_flag3 := flag3;
  request.uid := file_uid;
  request.chk_mask := access_mask;
  request.chk_flags2 := flags;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 124, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);

  result_out := reply.chk_result;
end;
