{ network_$ps_send_reply - send the page server's reply.

  Image addresses:
    sau2  0x00E10510  network_$ps_send_reply (nested)
    sau9  0x3C412938  network_$ps_send_reply (nested)

  - Each pass takes a header page, builds the internet header for the
    reply to the requester and sends it with the reply's data pages, up
    to as many tries as PKT_$BLD_INTERNET_HDR suggested.
  - A page-out reply (op 5) whose deadline has passed is not sent
    (NETWORK_$2LONG1 counted).
  - Nested in NETWORK_$PAGE_SERVER, which includes this fragment; every
    variable it names but its own is the server's.

  Status stored (in the server's status):
    net_io_$send's status: the last send
    pkt_$bld_internet_hdr's status: the header build failed
    status_$network_remote_node_failed_to_respond: the deadline passed
}

  procedure network_$ps_send_reply;
  label
    10;
  var
    send_info: net_io_$send_info_t;
    send_hdr: pkt_$hdr_ptr_t;
    hdr_va: pkt_$hdr_ptr_t;
    port: integer;
    timeout: pinteger;
    retries: integer;
    tries: pinteger;
    hdr_len: integer;
    limit: pinteger;
  begin
    pkt_info.flags := pkt_flags;
    tries := 0;

    repeat
      network_$gethdr(dest_node, hdr_va, hdr_pa);
      pkt_$bld_internet_hdr(routing_key, dest_node, dest_sock, src_node_or,
                            src_node, src_sock, pkt_info, request_id,
                            reply, reply_len, data_len, port, hdr_va^,
                            hdr_len, retries, timeout, status);
      limit := retries;

      if status.all <> status_$ok then
        goto 10;
      if (reply.ps.op = network_ps_reply_pagout) and then
         (network_$service_time + arrival.high < deadline.high) then begin
        network_$2long1 := network_$2long1 + 1;
        status.all := status_$network_remote_node_failed_to_respond;
        goto 10;
      end;

      send_hdr := hdr_va;
      net_io_$send(port, send_hdr, hdr_pa, hdr_len, 0, data_pages,
                   data_len, network_$reply_send_flags, send_info, status);
      network_$rtnhdr(hdr_va);

      if status.all = status_$ok then
        return;
      tries := tries + 1;
    until tries >= limit;
    return;

  10:
    network_$rtnhdr(hdr_va);
  end;
