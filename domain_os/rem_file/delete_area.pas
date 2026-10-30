{ REM_FILE_$DELETE_AREA - delete an area on a remote node.

  Image addresses:
    sau2  0x00E626CC  REM_FILE_$DELETE_AREA

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$delete_area(in node: uid_$t; remote_volx: pinteger;
                                caller_id: integer32;
                                out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_delete_area;
  request.area_volx := remote_volx;
  request.area_caller := caller_id;

  nil_word := 0;
  rem_file_$send_request(node, request, 28, nil_word, 0, reply, 190,
                         received_len, nil_word, 0, nil_word, packet_id,
                         status);
end;
