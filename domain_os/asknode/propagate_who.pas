{ ASKNODE_$PROPAGATE_WHO - pass a who request on, or answer a time one.

  Image addresses:
    sau2  0x00E65E8E  ASKNODE_$PROPAGATE_WHO

  - NETWORK_$REQUEST_SERVER calls it after ASKNODE_$SERVER filled ctx;
    a context marked done is left, else it is marked done after.
  - A time request (type 16#46) is answered to the node and socket ctx
    names; a who request is broadcast (node 2) on the caller's network.

  Status stored: none.
}

{ TODO(pascal) 10 frame bytes of PROPAGATE_WHO hold nothing

  The SAU2 image's frame has 10 bytes no instruction addresses (8 of
  them between pkt_info and status).  SERVER's frame has 8 bytes the
  same way (asknode/README.md).  The stand-ins unused_228 and
  unused_234 are sized so that dpc's layout gives the image's frame size
  and the offsets from status down; pkt_info still comes out 2 bytes
  off.  What the bytes were is not known. }

procedure asknode_$propagate_who(var ctx: asknode_$server_ctx_t;
                                 in routing: integer32);
var
  reply: asknode_$who_reply_t;
  pkt_info: asknode_$template_t;
  unused_228: array[1..4] of integer;     { stand-in, see the TODO }
  status: status_$t;
  timeout: pinteger;
  retry_hint: integer;
  template_len: pinteger;
  unused_234: integer;                    { stand-in, see the TODO }
begin
  if ctx.version = asknode_$done_marker then
    return;

  pkt_info := asknode_$pkt_info;
  pkt_info.addr_type := pkt_$addr_short;
  pkt_info.protocol := 16#BE;
  pkt_info.retry_limit := 0;

  if ctx.request_type = asknode_$reply_time_sync then begin
    reply.version := 3;
    reply.response_type := asknode_$reply_time_sync;
    reply.status.all := status_$ok;
    template_len := 8;
    pkt_info.flags := 16#20;
    pkt_$send_internet(ctx.args.param2, ctx.args.param1, ctx.socket,
                       routing, node_$me, 4, pkt_info, ctx.request_id,
                       reply, template_len, 0, 0, retry_hint, timeout,
                       status);
  end
  else begin
    pkt_info.flags := 16#B0;
    pkt_$send_internet(routing, 2, 4, routing, node_$me, ctx.socket,
                       pkt_info, ctx.request_id, ctx, 34, 0, 0,
                       retry_hint, timeout, status);
  end;

  ctx.version := asknode_$done_marker;
end;
