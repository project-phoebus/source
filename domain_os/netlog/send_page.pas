{ NETLOG_$SEND_PAGE - send the page to the logging server.

  Image addresses:
    sau2  0x00E71C78  NETLOG_$SEND_PAGE

  - Only when sending is on is the internet header built and the page
    (39 entries of 26 bytes, 1014 bytes) sent through NET_IO_$SEND; the
    statuses are dropped.

  Status stored: none.
}

{ TODO(pascal) hdr_va loaded into a register before the test it is used
  under

  The SAU2 image loads hdr_va into an address register before the test
  of ok_to_send, and uses the register only inside the `then' part.  A
  pointer local assigned from hdr_va at the top level would explain the
  register, but the frame has no 4 bytes for its slot (register-held
  locals keep theirs).  The source here passes hdr_va^ inside the `if';
  why its address is loaded early is not known (a loop-invariant or
  common-subexpression motion out of the `if' is not a known form). }

procedure netlog_$send_page;
var
  send_info: net_io_$send_info_t;
  hdr_pa: integer32;
  status: status_$t;
  hdr_va: pkt_$hdr_ptr_t;
  timeout: pinteger;
  retry_hint: integer;
  extra1: integer;
  pkt_len: integer;
  port: integer;
begin
  pkt_hdr.done_cnt := netlog_$done_cnt;
  pkt_hdr.entry_cnt := page_counts[send_page_index];

  network_$gethdr(netlog_$node, hdr_va, hdr_pa);

  if ok_to_send then
    pkt_$bld_internet_hdr(0, netlog_$node, netlog_$sock, -1, node_$me,
                          netlog_$sock, pkt_info, 0, pkt_hdr, 10,
                          1014, port, hdr_va^, pkt_len, retry_hint,
                          timeout, status);

  extra1 := 0;

  if ok_to_send and then (status.all = status_$ok) then
    net_io_$send(port, hdr_va, hdr_pa, pkt_len,
                 buffer_va[send_page_index],
                 lshft(buffer_ppn[send_page_index], 10),
                 1014, extra1, send_info, status);

  network_$rtnhdr(hdr_va);
end;
