{ ETHERNET_$SVC_WRITE - send a packet on a user channel.

  Image addresses:
    sau8  0x03C87464  ETHERNET_$SVC_WRITE
    sau9  0x3C483064  ETHERNET_$SVC_WRITE

  - The driver record's svc_write entry.  Under a cleanup handler the
    caller's vector, the whole frame from its Ethernet header on, is
    gathered into a fresh header page (up to 950 bytes after the page's
    tag word) and a data page (the rest); the source address is the
    unit's.  The frame goes out under the NET_IO lock.
  - A frame for this unit's own address, for all, or for a multicast
    address on the unit's list is also put into the socket of the
    channel that owns its type, tagged with its length.
  - A failed transmit counts in the tenth statistic, another error in
    the seventh; a full socket in the eighth.

  Status stored:
    ethernet_transmit's status: the frame was sent, or not
    status_$eth_invalid_unit_num: unit is not 0 or 1
    status_$eth_device_offline: the unit is not on line
    status_$eth_channel_not_open: channel is 0, above 10 or not open
    status_$eth_illegal_pkt_length: the frame, rounded up to even, is
      under 60 or over 1514 bytes
    status_$eth_invalid_pkt_type: the channel does not own the frame's
      type
    fim_$cleanup's status: a fault
}

procedure ethernet_$svc_write(var unit: pinteger; var channel: pinteger;
                              unused3: integer; var unused4: univ integer32;
                              var iov: univ ethernet_$iov_array_t;
                              iov_cnt: integer; var unused7: univ integer32;
                              out status: status_$t);
  options(val_param);
label
  release;
var
  info: sock_$pkt_info_t;
  crec: fim_$cleanup_rec_t;
  list: array[1..2] of ethernet_$xmit_piece_t;
  dst: integer32;
  cleanup_status: status_$t;
  xstatus: status_$t;
  data_pa: integer32;
  hdr_pa: integer32;
  data_va: integer32;
  hdr_va: integer32;
  sock: pinteger;
  off: integer;
  idx: integer;
  npieces: integer;
  total: pinteger;
  u: ethernet_$unit_ptr_t;
  h: ethernet_$rcv_hdr_ptr_t;
  hlen: pinteger;
  rest: pinteger;
  found: integer;
  i: integer;
begin
  if unit > eth_max_unit then begin
    status.all := status_$eth_invalid_unit_num;
    return;
  end;
  hdr_va := 0;
  data_pa := 0;
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

    { the frame's length, rounded up to even }
    total := 0;
    for i := 1 to iov_cnt do
      total := total + iov[i].len;
    total := (total + 1) & ~1;
    if (total < 60) or else (total > 1514) then begin
      fim_$rls_cleanup(crec);
      status.all := status_$eth_illegal_pkt_length;
      return;
    end;

    { the header page: the Ethernet header and what follows it }
    netbuf_$get_hdr(hdr_pa, hdr_va);
    h := ethernet_$rcv_hdr_ptr_t(hdr_va);
    hlen := min(total, 950);
    idx := 1;
    off := 0;
    list[1].va := addr(h^.eth);
    list[1].len := hlen;
    dst := integer32(list[1].va);
    ethernet_copy_data(iov, iov_cnt, idx, off, dst, list[1].len);

    { the channel must own the frame's type }
    found := 0;
    for i := 1 to u^.range_count do
      if (h^.eth.src.ptype >= u^.ranges[i].low)
         and then (h^.eth.src.ptype <= u^.ranges[i].high) then begin
        found := i;
        exit;
      end;
    if (found = 0) or else (u^.ranges[found].chan <> channel) then begin
      netbuf_$rtn_hdr(hdr_va);
      fim_$rls_cleanup(crec);
      status.all := status_$eth_invalid_pkt_type;
      return;
    end;
    h^.eth.src.addr := u^.station;

    { the data page: the rest }
    rest := total - hlen;
    if rest <> 0 then begin
      netbuf_$get_dat(data_pa);
      netbuf_$getva(data_pa, data_va, xstatus);
      ethernet_check_status(xstatus);
      list[2].va := univ_ptr(data_va);
      list[2].len := rest;
      dst := integer32(list[2].va);
      ethernet_copy_data(iov, iov_cnt, idx, off, dst, list[2].len);
      npieces := 2;
    end
    else begin
      data_pa := 0;
      npieces := 1;
    end;

    { the frame out }
    ml_$lock(ml_$net_io_lock);
    ethernet_transmit(u, addr(list), npieces, total, xstatus);
    ml_$unlock(ml_$net_io_lock);
    status := xstatus;
    if status.all = status_$eth_transmit_failed then
      with u^ do
        stats.counts[10] := stats.counts[10] + 1
    else if status.all <> status_$ok then
      with u^ do
        stats.counts[7] := stats.counts[7] + 1;
    if data_pa <> 0 then begin
      discard(netbuf_$rtnva(data_va));
      data_va := 0;
    end;

    { a frame for this unit too: into the owner's socket }
    if (h^.eth.dst = h^.eth.src.addr)
       or else ((h^.eth.dst.high = 16#FFFFFF)
                and then (h^.eth.dst.low = 16#FFFFFF))
       or else ethernet_mcast_listed(h^.eth.dst, u^.mcast,
                                     u^.mcast_count) then begin
      h^.tag.tag := total;
      sock := u^.channels[u^.ranges[found].chan].socket;
      info.hdr := hdr_va;
      info.data_pages[1] := data_pa;
      info.hdr_len := hlen;
      info.data_len := rest;
      info.flags := [];
      info.n_hops := 0;
      time_$abs_clock(info.src_addr);
      if sock_$put(sock, info, false, 4, u^.cnum) then
        goto release;
      with u^ do
        stats.counts[8] := stats.counts[8] + 1;
    end;

    { the pages not consumed }
    netbuf_$rtn_hdr(hdr_va);
    hdr_va := 0;
    if data_pa <> 0 then begin
      netbuf_$rtn_dat(data_pa);
      data_pa := 0;
    end;

  release:
    fim_$rls_cleanup(crec);
  end

  else begin
    { a fault }
    if hdr_va <> 0 then
      netbuf_$rtn_hdr(hdr_va);
    if data_va <> 0 then
      discard(netbuf_$rtnva(data_va));
    if data_pa <> 0 then
      netbuf_$rtn_dat(data_pa);
    status := cleanup_status;
  end;
end;
