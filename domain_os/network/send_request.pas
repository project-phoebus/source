{ network_$send_request - build and transmit a request to a partner node.

  Image addresses:
    sau2  0x00E0F5F4  network_$send_request (module-local)
    sau6  0x7800FF62  network_$send_request (module-local)
    sau7  0x3C41147A  network_$send_request (module-local)
    sau8  0x03C1092A  network_$send_request (module-local)

  - Each pass takes a header page, builds the internet header for the
    request and sends it with the data page; on a failed send it waits
    NETWORK_$RETRY_DELAY and goes round again.
  - The retry limit is PKT_$BLD_INTERNET_HDR's; the mother node has
    none.

  Status stored:
    status_$ok: the send succeeded, or its transmit bits 10, 2, 6 or 5
    status_$network_memory_parity_error_during_transmit: as it was sent
    status_$network_too_many_transmit_retries: transmit status 16#2000,
      or the retries spent (not to the mother node)
    pkt_$bld_internet_hdr's status: the header build failed
}

{ TODO(pascal) hdr_va stored back after PKT_$BLD_INTERNET_HDR

  hdr_va is loaded into an address register for the header argument
  and, after the call, the register is stored back into hdr_va, though
  nothing between changes either.  `hdr_va^' passed by address gives
  the push but no store back; a source that assigns hdr_va (from a copy
  held in the register) after the call would give the store but has no
  evident reason.  The construct is not identified; the Pascal passes
  hdr_va^. }

{ TODO(pascal) network_$send_request's frame

  The frame (0x1C bytes): the reserved slot, info, hdr_pa, hdr_va,
  hdr_len, port.  Not addressed: 4 bytes between hdr_pa and hdr_va and 2
  at the bottom; retries and the register-held parameters would have
  slots, but which of them the original's
  locals were is not known. }

procedure network_$send_request(in node_addr: uid_$t; sock_num: integer;
                                pkt_id: integer;
                                in cmd_buf: univ pkt_$hdr_t;
                                cmd_len: integer; data_pa: integer32;
                                data_len: pinteger;
                                out retry_out: pinteger;
                                out timeout_out: pinteger;
                                out status_ret: status_$t); internal;
label
  10;
type
  xmit_bits_t = set of 0..15;
var
  info: net_io_$send_info_t;
  hdr_pa: integer32;
  hdr_va: pkt_$hdr_ptr_t;
  hdr_len: integer;
  port: integer;
  retries: pinteger;
begin
  retries := 0;

  repeat
    network_$gethdr(node_addr.low, hdr_va, hdr_pa);
    pkt_$bld_internet_hdr(node_addr.high, node_addr.low, 1, -1, node_$me,
                          sock_num, network_$request_pkt_info, pkt_id,
                          cmd_buf, cmd_len, data_len, port, hdr_va^,
                          hdr_len, retry_out, timeout_out, status_ret);

    if status_ret.all <> status_$ok then begin
      network_$rtnhdr(hdr_va);
      return;
    end;

    net_io_$send(port, hdr_va, hdr_pa, hdr_len, 0, data_pa, data_len,
                 network_$request_send_flags, info, status_ret);
    network_$rtnhdr(hdr_va);

    if (status_ret.all = status_$ok) or else
       (status_ret.all = status_$network_memory_parity_error_during_transmit)
    then
      return;

    if info.port_net = 0 then begin
      if (info.xmit_status = 16#2000) and then
         (node_addr.low <> network_$mother_node) then
        goto 10;
      if (10 in xmit_bits_t(info.xmit_status)) or else
         (2 in xmit_bits_t(info.xmit_status)) or else
         (6 in xmit_bits_t(info.xmit_status)) or else
         (5 in xmit_bits_t(info.xmit_status)) then begin
        status_ret.all := status_$ok;
        return;
      end;
    end;

    { unsigned }
    retries := retries + 1;
    if (retries > retry_out) and then
       (node_addr.low <> network_$mother_node) then
      goto 10;

    time_$wait(time_$relative, network_$retry_delay, status_ret);
  until false;

10:
  status_ret.all := status_$network_too_many_transmit_retries;
end;
