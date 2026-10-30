{ REM_FILE_$ACL_CREATE - create an ACL object on a remote node.

  Image addresses:
    sau2  0x00E6283C  REM_FILE_$ACL_CREATE

  - Two requests: a new UID, then the creation with the ACL image (1024
    bytes) as the request's data.  The reply's ACL UID is handed back
    whatever the second's status.

  Status stored:
    status_$ok: the second request answered a duplicate UID
    rem_file_$send_request's status: the first failed, or the second's
}

procedure rem_file_$acl_create(in addr_info: integer32;
                               in acl_data: univ rem_file_$acl_buf_t;
                               in acl_header: acl_$prot_data_t;
                               in parent_uid: uid_$t;
                               out acl_uid_out: uid_$t;
                               out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  { a new UID }
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_generate_uid;
  nil_word := 0;
  rem_file_$send_request(addr_info, request, 16, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);

  if status.all <> status_$ok then
    return;

  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_acl_create;
  request.uid := parent_uid;
  request.acl_header := acl_header;
  request.acl_flags := rem_file_acl_req_flags;
  request.acl_session := reply.reply_uid;

  rem_file_$send_request(addr_info, request, 72, acl_data, 1024,
                         reply, 190, received_len, nil_word, 0, nil_word,
                         packet_id, status);

  if status.all = status_$vtoc_duplicate_uid then
    status.all := status_$ok;

  acl_uid_out := reply.acl_new_uid;
end;
