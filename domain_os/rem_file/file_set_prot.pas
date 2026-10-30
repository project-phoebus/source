{ REM_FILE_$FILE_SET_PROT - set an object's protection on the object's
  home node.

  Image addresses:
    sau2  0x00E62B64  REM_FILE_$FILE_SET_PROT

  - mtime_out is the object's modification time from a full reply (190
    bytes), else the local clock.

  Status stored:
    rem_file_$send_request's status: always
}

procedure rem_file_$file_set_prot(var addr_info: integer32;
                                  in file_uid: uid_$t;
                                  in value: file_$attr_value_t;
                                  attr_type: integer;
                                  in exsid: acl_$exsid_t;
                                  subsys_flag: boolean;
                                  out mtime_out: time_$clock_t;
                                  out status: status_$t);
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_file_set_prot;
  request.fsp_exsid := exsid;
  request.uid := file_uid;
  request.fsp_value.value := value;
  request.fsp_type := attr_type;
  request.fsp_subsys := subsys_flag;

  nil_word := 0;
  rem_file_$send_request(addr_info, request, 168, nil_word, 0, reply,
                         190, received_len, nil_word, 0, nil_word,
                         packet_id, status);

  if received_len = 190 then
    mtime_out := reply.mtime
  else
    time_$clock(mtime_out);
end;
