{ REM_FILE_$TEST - send a test request to a node.

  Image addresses:
    sau2  0x00E62374  REM_FILE_$TEST

  - The request goes with 18 bytes.

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$test(in addr_info: integer32; out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_test;
  request.uid := uid_$nil;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 18, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);
end;
