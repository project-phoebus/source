{ REM_FILE_$INVALIDATE - invalidate a range of an object's pages on its
  home node.

  Image addresses:
    sau2  0x00E623D8  REM_FILE_$INVALIDATE

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$invalidate(var addr_info: integer32;
                               in file_uid: uid_$t; start: integer32;
                               count: integer32; flag: boolean;
                               out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_invalidate;
  request.uid := file_uid;
  request.inv_start := start;
  request.inv_count := count;
  request.inv_flag := flag;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 22, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);
end;
