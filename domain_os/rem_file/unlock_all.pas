{ REM_FILE_$UNLOCK_ALL - tell every node to drop this node's locks.

  Image addresses:
    sau2  0x00E61C72  REM_FILE_$UNLOCK_ALL

  - One broadcast straight through PKT_$SEND_INTERNET, with no reply
    awaited; its status is dropped.

  Status stored: none.
}

procedure rem_file_$unlock_all;
var
  pkt_info: rem_file_$pkt_view_t;
  request: rem_file_$req_t;
  status: status_$t;
  timeout: pinteger;
  retry_hint: integer;
begin
  request.hdr.msg_type := 1;
  request.hdr.magic := rem_file_req_magic;
  request.hdr.opcode := rem_file_op_unlock_all;
  request.uid := uid_$nil;
  request.all_version := rem_file_req_version;
  request.all_super := acl_$super_count[proc1_$current] > 0;

  pkt_info.tmpl := rem_file_$pkt_info;
  pkt_info.flags_set := pkt_info.flags_set + [7];

  pkt_$send_internet(0, 0, 2, 0, node_$me, 16#270F, pkt_info, 0, request,
                     16#10, 0, 0, retry_hint, timeout, status);
end;
