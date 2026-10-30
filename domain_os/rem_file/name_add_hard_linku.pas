{ REM_FILE_$NAME_ADD_HARD_LINKU - add a hard link to a directory on
  another node.

  Image addresses:
    sau2  0x00E624EC  REM_FILE_$NAME_ADD_HARD_LINKU

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$name_add_hard_linku(var addr_info: integer32;
                                        in dir_uid: uid_$t;
                                        in name: univ name_$name_t;
                                        name_len: pinteger;
                                        in file_uid: uid_$t;
                                        out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.ahl_name[1] := ' ';
  request.ahl_name[2] := ' ';
  request.ahl_name[3] := ' ';
  request.ahl_name[4] := ' ';

  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_name_add_hard_linku;
  request.uid := dir_uid;
  request.ahl_name := name;
  request.ahl_name_len := name_len;
  request.ahl_file_uid := file_uid;
  request.ahl_version := rem_file_req_version;
  request.ahl_force := true;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 58, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);
end;
