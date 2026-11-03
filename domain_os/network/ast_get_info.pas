{ NETWORK_$AST_GET_INFO - fetch a remote object's location and attributes.

  Image addresses:
    sau2  0x00E1026C  NETWORK_$AST_GET_INFO
    sau8  0x03C11588  NETWORK_$AST_GET_INFO

  - The client half of request 6 (reply 7), to the node at
    loc.node_addr; refused unless paging service is allowed.
  - A reply of 184 bytes (a new server) gives the attribute record and
    the location record.  An older server's 64-byte record is converted
    by VTOCE_$OLD_TO_NEW and the location record rebuilt in place.
  - The old arm sets loc.remote, which the common tail then recomputes
    from the node address.

  Status stored:
    status_$ok: the reply was taken
    status_$network_request_denied_by_local_node: paging not allowed
    network_$do_request's status: the request failed
}

procedure network_$ast_get_info(in out loc: network_$obj_loc_t;
                                in flags: integer;
                                out attrs: network_$attr_rec_t;
                                out status_ret: status_$t);
var
  request: network_$ps_rqst_t;
  reply: network_$ps_reply_t;
  reply_len: integer;
begin
  if not (network_service_paging in network_$allowed_service.service)
  then begin
    status_ret.all := status_$network_request_denied_by_local_node;
    return;
  end;

  request.op := network_ps_rqst_getattr;
  request.uid := loc.uid;
  request.flags := flags;
  request.version := 8;
  request.loc := loc;

  network_$do_request(loc.node_addr, request, 50, 0, 0, false, reply,
                      reply_len, status_ret);
  if status_ret.all <> status_$ok then
    return;

  if reply_len = 184 then begin
    { a new server }
    if flags <> 0 then
      attrs := reply.attrs;
    reply.loc.node_addr := loc.node_addr;
    loc := reply.loc;
  end
  else begin
    { an old server }
    if flags <> 0 then begin
      vtoce_$old_to_new(reply.old_attrs, attrs);
      attrs.hdr_bits := attrs.hdr_bits + [0];
    end;
    loc.remote := true;
    loc.byte_00 := 0;
    loc.long_02 := 0;
    loc.word_06 := 0;
    loc.rights := 0;
    loc.lo_1d := 1;
    loc.lo_01 := 1;
    loc.scratch := true;
  end;

  loc.remote := loc.node_addr.low <> node_$me;
end;
