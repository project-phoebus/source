{ REM_FILE_$CREATE_AREA - create an area on a remote (diskless partner)
  node.

  Image addresses:
    sau2  0x00E62622  REM_FILE_$CREATE_AREA

  - The result is the area's handle; local_volx is the packet size
    NETWORK_$GET_PKT_SIZE settles from the reply's (1024 for a reply of
    10 bytes or fewer).
  - shared is not read.

  Status stored:
    rem_file_$send_request's status: always
}

function rem_file_$create_area(in node: uid_$t; total_size: integer32;
                               total_commit: integer32;
                               caller_id: integer32; shared: boolean;
                               out local_volx: integer;
                               out status: status_$t): integer;
var
  reply: rem_file_$reply_t;
  request: rem_file_$req_t;
  pkt_size: pinteger;
  nil_word: integer;
  packet_id: pinteger;
  received_len: integer;
begin
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_create_area;
  request.area_size := total_size;
  request.area_commit := total_commit;
  request.area_caller := caller_id;

  nil_word := 0;
  rem_file_$send_request(node, request, 28, nil_word, 0, reply, 190,
                         received_len, nil_word, 0, nil_word, packet_id,
                         status);

  if received_len <= 10 then
    pkt_size := 1024
  else
    pkt_size := reply.ca_pkt_size;

  local_volx := network_$get_pkt_size(node, pkt_size);

  rem_file_$create_area := reply.ca_handle;
end;
