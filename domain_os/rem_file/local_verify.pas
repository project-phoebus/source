{ REM_FILE_$LOCAL_VERIFY - ask a lock's holder node whether it still holds
  the lock.

  Image addresses:
    sau2  0x00E61E20  REM_FILE_$LOCAL_VERIFY

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$local_verify(in addr_info: integer32;
                                 in lock_block: file_$lock_info_t;
                                 out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_local_verify;
  request.uid := lock_block.file_uid;
  request.verify_lock := lock_block;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 46, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);
end;
