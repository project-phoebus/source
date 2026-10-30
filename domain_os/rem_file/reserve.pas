{ REM_FILE_$RESERVE - reserve disk space for an object on its home node.

  Image addresses:
    sau2  0x00E62458  REM_FILE_$RESERVE

  Status stored:
    status_$ok: an old server's "bad reply" (opcode byte 3), which does
      not know the operation
    rem_file_$send_request's status: otherwise
}

procedure rem_file_$reserve(var addr_info: integer32; in file_uid: uid_$t;
                            start: integer32; count: integer32;
                            out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_reserve;
  request.uid := file_uid;
  request.res_start := start;
  request.res_count := count;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 22, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);

  if (status.all = file_$bad_reply_received_from_remote_node) and then
     (reply.hdr.opcode = rem_file_op_bad_version_reply) then
    status.all := status_$ok;
end;
