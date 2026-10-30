{ REM_FILE_$PURIFY - have an object's pages written out on its home node.

  Image addresses:
    sau2  0x00E6225C  REM_FILE_$PURIFY

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$purify(var addr_info: integer32; in file_uid: uid_$t;
                           var flags: pinteger; page_index: integer;
                           out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_purify;
  request.uid := file_uid;
  request.pur_flags := flags;
  request.pur_page := page_index;
  request.pur_version := rem_file_req_version;

  request.pur_super := acl_$super_count[proc1_$current] > 0;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 20, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);
end;
