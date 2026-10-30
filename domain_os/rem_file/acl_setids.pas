{ REM_FILE_$ACL_SETIDS - have a remote node bring an ACL's SIDs up to
  date.

  Image addresses:
    sau2  0x00E62930  REM_FILE_$ACL_SETIDS

  - When the node changed them, its SID block and project list replace
    the caller's.

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$acl_setids(in addr_info: integer32;
                               in acl_uid: uid_$t;
                               in out sid_data: acl_sid_block_t;
                               in out owner_data: acl_proj_list_t;
                               out modified_flag_out: boolean;
                               out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_acl_setids;
  request.ids_flags := rem_file_acl_req_flags;
  request.ids_sids := sid_data;
  request.ids_owner := owner_data;
  request.uid := acl_uid;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 64, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);

  modified_flag_out := reply.ids_modified;
  if modified_flag_out then begin
    sid_data := reply.ids_sids;
    owner_data := reply.ids_owner;
  end;
end;
