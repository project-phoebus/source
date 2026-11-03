{ NETWORK_$WRITE - write pages to a remote node's page server.

  Image addresses:
    sau2  0x00E0FAE6  NETWORK_$WRITE
    sau8  0x03C10E14  NETWORK_$WRITE

  - count pages from physical page ppn go as page-out requests of the
    node's packet size, each with the data's checksum when
    NETWORK_$DO_CHKSUM is set (else 0).
  - The first reply gives the object's DTM, as much of it as the
    reply's version carries.

  Status stored:
    network_$do_request's status: the last request
}

{ TODO(pascal) NETWORK_$WRITE's frame

  The frame (0x110 bytes): the reserved slot, request (0x2A), reply
  (0xB8), info, and the GET_CHKSUM operands' temporaries (chunk, pa).
  Not addressed: 0x1A bytes between the reserved slot and the request, 4
  between the reply and the temporaries, and 4 at the bottom; the
  register-held locals (chunk, remaining, first, pa: 12 bytes) explain
  part of the first only, and info below the temporaries is not
  explained. }

procedure network_$write(in node_addr: uid_$t;
                         in req: network_$page_request_t;
                         ppn: linteger; pkt_size: integer;
                         count: pinteger; out dtv_low: pinteger;
                         out dtm: time_$clock_t; out status: status_$t);
var
  request: network_$pagout_rqst_t;
  reply: network_$pagout_reply_t;
  info: integer;
  chunk: pinteger;
  remaining: integer32;
  first: boolean;
  pa: integer32;
begin
  chunk := network_$get_pkt_size(node_addr, pkt_size);
  first := true;
  remaining := count;
  request.op := network_ps_rqst_pagout;
  request.flag := first;
  request.version := 8;
  request.req := req;
  pa := ppn * 1024;

  repeat
    if network_$do_chksum then
      request.chksum := get_chksum(pa, chunk)
    else
      request.chksum := 0;
    network_$write_call_cnt := network_$write_call_cnt + 1;

    network_$do_request(node_addr, request, 16#2A, pa, chunk, false,
                        reply, info, status);
    if status.all <> status_$ok then
      return;

    if first then begin
      first := false;
      if reply.version >= 6 then begin
        dtv_low := reply.dtm_low;
        dtm := reply.clock;
      end
      else if reply.version >= 4 then begin
        dtv_low := reply.dtm_low;
        dtm.high := reply.dtm_high;
        dtm.low := dtv_low;
      end
      else begin
        dtv_low := lshft(ord(reply.dtm_bits), 8) & 16#F800;
        dtm.high := reply.dtm_high;
        dtm.low := dtv_low;
      end;
    end;

    pa := pa + chunk;
    request.req.page_num := request.req.page_num + chunk div 1024;
    remaining := remaining - chunk div 1024;
  until remaining <= 0;
end;
