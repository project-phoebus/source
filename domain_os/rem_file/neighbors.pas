{ REM_FILE_$NEIGHBORS - ask a node whether two objects lie on one volume.

  Image addresses:
    sau2  0x00E621B8  REM_FILE_$NEIGHBORS

  - The result is the reply's answer, false when the request failed.

  Status stored:
    rem_file_$send_request's status: always
}

function rem_file_$neighbors(in addr_info: integer32; in uid1: uid_$t;
                             in uid2: uid_$t;
                             out status: status_$t): boolean;
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_neighbors;
  request.uid := uid1;
  request.nb_uid2 := uid2;
  request.nb_version := rem_file_req_version;

  request.nb_super := acl_$super_count[proc1_$current] > 0;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 24, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);

  if status.all = status_$ok then
    rem_file_$neighbors := reply.nb_result
  else
    rem_file_$neighbors := false;
end;
