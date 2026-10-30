{ REM_FILE_$ACL_IMAGE - fetch an object's ACL image from its home node.

  Image addresses:
    sau2  0x00E627A8  REM_FILE_$ACL_IMAGE

  - The image comes back as the reply's bulk data, up to 1024 bytes,
    with its length and the protection record.

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$acl_image(var addr_info: integer32;
                              in file_uid: uid_$t;
                              acl_type: boolean;
                              var acl_image_out: univ rem_file_$acl_buf_t;
                              out acl_len_out: integer;
                              out acl_header_out: acl_$prot_data_t;
                              out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  bulk_len: integer;
  received_len: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_acl_image;
  request.uid := file_uid;
  request.img_type := acl_type;
  request.img_flags := rem_file_acl_req_flags;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 20, nil_word, 0, reply,
                         190, received_len, acl_image_out, 1024,
                         bulk_len, packet_id, status);

  acl_len_out := reply.img_len;
  acl_header_out := reply.img_header;
end;
