{ PKT_$SEND_INTERNET - send an internet packet, with retries.

  Image addresses:
    sau2  0x00E1264E  PKT_$SEND_INTERNET

  - The data are copied into data pages; then up to the retry limit a
    header is built (PKT_$BLD_INTERNET_HDR) and sent (NET_IO_$SEND),
    25000 ticks between tries unless the driver refused the packet.
  - A quit while waiting ends the tries; the header and data pages are
    given back at the end.

  Status stored:
    net_io_$send's status: the last try
    pkt_$bld_internet_hdr's status: a header could not be built
    status_$network_msg_header_too_big: a template over 512 bytes
    time_$wait_quit: a quit while waiting
}

procedure pkt_$send_internet(routing_key: integer32;
                             dest_node: integer32;
                             dest_sock: integer;
                             src_node_or: integer32;
                             src_node: integer32;
                             src_sock: integer;
                             in pkt_info: univ pkt_$info_t;
                             request_id: pinteger;
                             in template: univ pkt_$bytes_t;
                             template_len: pinteger;
                             in data: univ pkt_$bytes_t;
                             data_len: integer;
                             out retry_hint: integer;
                             out timeout_out: pinteger;
                             out status_ret: status_$t);
  options(val_param);
var
  data_pages: pkt_$data_pages_t;
  send_info: net_io_$send_info_t;
  retry_delay: time_$clock_t;
  hdr_pa: integer32;
  wait_status: status_$t;
  status: status_$t;
  unused_2c: integer32;                   { stand-in }
  hdr: pkt_$hdr_ptr_t;
  port: integer;
  attempt: pinteger;
  max_attempts: pinteger;
  total_len: integer;
begin
  data_pages[1] := 0;
  if template_len > 512 then begin
    status_ret.all := status_$network_msg_header_too_big;
    return;
  end;

  if data_len > 0 then
    pkt_$copy_to_pa(data, data_len, data_pages, status_ret);

  if pkt_info.retry_limit = 0 then
    max_attempts := 16#FFFF
  else
    max_attempts := pkt_info.retry_limit;
  attempt := 0;

  { the tries }
  repeat
    attempt := attempt + 1;
    network_$gethdr(dest_node, hdr, hdr_pa);
    pkt_$bld_internet_hdr(routing_key, dest_node, dest_sock, src_node_or,
                          src_node, src_sock, pkt_info, request_id,
                          template, template_len, data_len, port, hdr^,
                          total_len, retry_hint, timeout_out, status);
    if status.all <> status_$ok then
      exit;
    if max_attempts = 16#FFFF then
      max_attempts := retry_hint;
    net_io_$send(port, hdr, hdr_pa, total_len, 0, data_pages, data_len,
                 pkt_$default_flags, send_info, status);
    if status.all = status_$ok then
      exit;
    network_$rtnhdr(hdr);
    hdr := nil;
    if (send_info.port_net = 0) and (send_info.xmit_status = 16#2000) then
      exit;
    retry_delay.high := 0;
    retry_delay.low := 25000;
    time_$wait(time_$relative, retry_delay, wait_status);
    if wait_status.all = time_$wait_quit then begin
      status := wait_status;
      exit;
    end;
  until attempt >= max_attempts;

  if hdr <> nil then
    network_$rtnhdr(hdr);
  pkt_$dump_data(data_pages, data_len);
  status_ret := status;
end;
