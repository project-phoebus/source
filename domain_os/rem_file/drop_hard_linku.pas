{ REM_FILE_$DROP_HARD_LINKU - drop a hard link from a directory on
  another node.

  Image addresses:
    sau2  0x00E62588  REM_FILE_$DROP_HARD_LINKU

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$drop_hard_linku(var addr_info: integer32;
                                    in dir_uid: uid_$t;
                                    in name: univ name_$name_t;
                                    name_len: pinteger; flag: integer;
                                    out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.dhl_name[1] := ' ';
  request.dhl_name[2] := ' ';
  request.dhl_name[3] := ' ';
  request.dhl_name[4] := ' ';

  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_drop_hard_linku;
  request.uid := dir_uid;
  request.dhl_name := name;
  request.dhl_name_len := name_len;
  request.dhl_flag := flag;
  request.dhl_version := rem_file_req_version;
  request.dhl_force := true;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 52, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);
end;
