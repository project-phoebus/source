{ ETHERNET_$SVC_READ - receive a packet on a user channel.

  Image addresses:
    sau6  0x78089296  ETHERNET_$SVC_READ
    sau7  0x3C49399E  ETHERNET_$SVC_READ
    sau8  0x03C8719A  ETHERNET_$SVC_READ
    sau9  0x3C482D9A  ETHERNET_$SVC_READ

  - The driver record's svc_read entry.  Under a cleanup handler the
    next packet is taken off the channel's socket and its header page
    (from the Ethernet header on) and data page scattered into the
    caller's vector; len_out is the length the header page's tag word
    holds.  The pages go back as they are copied, and on a fault
    whatever is still held.
  - A packet with more than 1024 bytes of data is dropped.

  Status stored:
    status_$ok: a packet was received
    status_$eth_invalid_unit_num: unit is not 0 or 1
    status_$eth_device_offline: the unit is not on line
    status_$eth_channel_not_open: channel is 0, above 10 or not open
    status_$eth_no_packet_to_receive: the socket holds no packet
    status_$network_msg_exceeds_max_size: the packet's data is too long
    netbuf_$getva's status: the data page could not be mapped
    fim_$cleanup's status: a fault
}

procedure ethernet_$svc_read(var unit: pinteger; var channel: pinteger;
                             unused3: integer; var unused4: univ integer32;
                             var iov: univ ethernet_$iov_array_t;
                             iov_cnt: integer; out len_out: integer;
                             out status: status_$t);
  options(val_param);
var
  info: sock_$pkt_info_t;
  crec: fim_$cleanup_rec_t;
  data_pa: pkt_$data_pages_t;
  cleanup_status: status_$t;
  u: ethernet_$unit_ptr_t;
  data_va: integer32;
  hdr_va: integer32;
  off: integer;
  idx: integer;
  data_len: integer;
  hdr_len: integer;
  src: integer32;
begin
  if unit > eth_max_unit then begin
    status.all := status_$eth_invalid_unit_num;
    return;
  end;
  hdr_va := 0;
  data_pa[1] := 0;
  data_va := 0;

  cleanup_status := fim_$cleanup(crec);
  if cleanup_status.all = fault_$cleanup_set then begin
    { the unit, the channel }
    u := addr(ether_ucb[unit]);
    if not (eth_unit_online in u^.flags) then begin
      fim_$rls_cleanup(crec);
      status.all := status_$eth_device_offline;
      return;
    end;
    if (channel = 0) or else (channel > 10)
       or else not u^.channels[channel].open then begin
      fim_$rls_cleanup(crec);
      status.all := status_$eth_channel_not_open;
      return;
    end;

    { a packet }
    if not sock_$get(u^.channels[channel].socket, info) then begin
      fim_$rls_cleanup(crec);
      status.all := status_$eth_no_packet_to_receive;
      return;
    end;
    hdr_va := info.hdr;
    hdr_len := info.hdr_len;
    data_len := info.data_len;
    data_pa[1] := info.data_pages[1];
    if data_len > 1024 then begin
      netbuf_$rtn_hdr(hdr_va);
      pkt_$dump_data(info.data_pages, data_len);
      fim_$rls_cleanup(crec);
      status.all := status_$network_msg_exceeds_max_size;
      return;
    end;

    { the header page }
    len_out := ethernet_$rcv_hdr_ptr_t(hdr_va)^.tag.tag;
    idx := 1;
    off := 0;
    src := integer32(addr(ethernet_$rcv_hdr_ptr_t(hdr_va)^.eth));
    ethernet_copy_to_user(src, hdr_len, iov, iov_cnt, idx, off);
    netbuf_$rtn_hdr(hdr_va);
    hdr_va := 0;

    { the data page }
    if data_pa[1] <> 0 then begin
      netbuf_$getva(data_pa[1], data_va, status);
      ethernet_check_status(status);
      ethernet_copy_to_user(data_va, data_len, iov, iov_cnt, idx, off);
      netbuf_$rtn_dat(netbuf_$rtnva(data_va));
      data_va := 0;
      data_pa[1] := 0;
    end;

    fim_$rls_cleanup(crec);
    status.all := status_$ok;
  end

  else begin
    { a fault }
    if hdr_va <> 0 then
      netbuf_$rtn_hdr(hdr_va);
    if data_va <> 0 then
      discard(netbuf_$rtnva(data_va));
    if data_pa[1] <> 0 then
      netbuf_$rtn_dat(data_pa[1]);
    status := cleanup_status;
  end;
end;
