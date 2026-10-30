{ NETWORK_$RING_INFO - fetch a node's token-ring record.

  Image addresses:
    sau2  0x00E1039A  NETWORK_$RING_INFO

  - Request 16#0E (the op only, 2 bytes) goes to the node; when it
    succeeds, the 122-byte token-ring record at the reply's +6 is
    returned.

  Status stored:
    network_$do_request's status: in either case
}

procedure network_$ring_info(in node_addr: uid_$t;
                             out info: network_$ring_info_t;
                             out status_ret: status_$t);
var
  request: network_$ps_rqst_t;
  reply: network_$ps_reply_t;
  status: status_$t;
  reply_len: integer;
begin
  request.op := network_ps_rqst_ring_info;
  network_$do_request(node_addr, request, 2, 0, 0, false, reply,
                      reply_len, status);

  status_ret := status;
  if status.all = status_$ok then
    info := reply.ring;
end;
