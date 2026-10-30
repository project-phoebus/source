{ REM_FILE_$TRUNCATE - truncate an object on its home node.

  Image addresses:
    sau2  0x00E61976  REM_FILE_$TRUNCATE

  - dtm_out is the reply's new modification time when the reply has one
    (16 bytes), else the local clock.

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$truncate(var addr_info: integer32; in uid: uid_$t;
                             new_size: integer32; flags: boolean;
                             out dtm_out: time_$clock_t;
                             out status: status_$t);
  options(val_param);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_truncate;
  request.uid := uid;
  request.trunc_flags := flags;
  request.trunc_size := new_size;
  request.trunc_version := rem_file_req_version;
  request.trunc_super := acl_$super_count[proc1_$current] > 0;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 22, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);

  if received_len = 16 then
    dtm_out := reply.reply_clock
  else
    time_$clock(dtm_out);
end;
