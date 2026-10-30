{ REM_FILE_$SET_ATTRIBUTE - set one attribute of an object on its home
  node.

  Image addresses:
    sau2  0x00E61A32  REM_FILE_$SET_ATTRIBUTE

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$set_attribute(var addr_info: integer32;
                                  in file_uid: uid_$t; attr_id: integer;
                                  in value: file_$attr_value_t;
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
  request.hdr.opcode := rem_file_op_set_attribute;
  request.uid := file_uid;
  request.attr_id := attr_id;
  request.attr_value := value;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 66, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);
end;
