{ ETHERNET_$SEND_OS - send a MAC_OS packet on a system channel.

  Image addresses:
    sau8  0x03C8827A  ETHERNET_$SEND_OS
    sau9  0x3C483E7A  ETHERNET_$SEND_OS

  - The driver record's send_os entry.  The Ethernet header goes in the
    14 bytes before the caller's header when that header starts 14
    bytes into its page, else in a header of its own sent as a piece
    before it.  The header and data are rounded up to even and the
    frame padded to 60 bytes.
  - The destination: a three-word link address as it is; a two-word
    one, a node ID, as Apollo's block and its low 24 bits, resolved by
    the ARP cache (as is any address in Apollo's block).
  - The frame goes out under the NET_IO lock; one for this unit's own
    address, for all or for a multicast address on the unit's list is
    also looped back, copied, through MAC_OS_$DEMUX.
  - A failed transmit counts in the tenth statistic, another error in
    the seventh.  A failed copy or loopback is not reported.

  Status stored:
    ethernet_transmit's status: the frame was sent, or not
    status_$eth_device_offline: the unit's receive process is not
      running
    status_$eth_channel_not_open: the channel is 0, above 10 or not
      open
    status_$eth_illegal_pkt_length: a length is negative, or the frame
      is over 1514 bytes
    status_$eth_illegal_dest_address: the link address is not two or
      three words
}

{ TODO(pascal) the stand-in local of ETHERNET_$SEND_OS

  The routine's frame has about a kilobyte between the pieces' list and
  the node ID that no instruction addresses, here and in the SAU6, SAU7
  and SAU8 copies of the routine.  unused_buf stands for whatever the
  original declared there; the list's own length is not known either
  (four pieces at most are used), so the stand-in's size is the room
  after a four-piece list. }

procedure ethernet_$send_os(line: integer; var callback_data: pinteger;
                            var pkt: mac_os_$send_pkt_t;
                            out bytes_sent: integer; out status: status_$t);
  options(val_param);
type
  { The Ethernet header, or its first three words (the destination). }
  hdr_view_t = record
    case integer of
      1: (eth: ethernet_$eth_hdr_t);
      2: (words: array[0..6] of integer);
  end;
  hdr_view_ptr_t = ^hdr_view_t;

  { A two-word link address: a node ID, its low 24 bits a station's. }
  link_view_t = packed record
    n_words: integer;                     { 0x00 }
    node_high: 0..255;                    { 0x02 }
    node_low: 0..16#FFFFFF;               { 0x03 }
  end;
  link_view_ptr_t = ^link_view_t;
var
  rpkt: mac_os_$rcv_pkt_t;
  new_pages: pkt_$data_pages_t;
  ehdr: hdr_view_t;
  pad: array[1..46] of char;
  list: array[1..4] of ethernet_$xmit_piece_t;
  unused_buf: array[1..1080] of char;     { stand-in, see the TODO }
  node: linteger;
  new_hdr: integer32;
  src_va: integer32;
  st: status_$t;
  hdr_page: pkt_$hdr_ptr_t;
  eh: hdr_view_ptr_t;
  demux_flag: boolean;
  u: ethernet_$unit_ptr_t;
  off: integer32;
  own_hdr: boolean;
  hlen: pinteger;
  dlen: pinteger;
  total: pinteger;
  n: integer;
  i: integer;
begin
  bytes_sent := 0;
  u := addr(ether_ucb[line]);
  if not (eth_unit_rcv_proc in u^.flags) then begin
    status.all := status_$eth_device_offline;
    return;
  end;
  if (callback_data = 0) or else (callback_data > 10)
     or else not u^.channels[callback_data].open then begin
    status.all := status_$eth_channel_not_open;
    return;
  end;

  { the lengths }
  hlen := (pkt.hdr_desc.length + 1) & ~1;
  dlen := (pkt.data_length + 1) & ~1;
  total := hlen + dlen + 14;
  if (pkt.hdr_desc.length < 0) or else (pkt.data_length < 0)
     or else (total > 1514) then begin
    status.all := status_$eth_illegal_pkt_length;
    return;
  end;

  { the Ethernet header: before the caller's, or of its own }
  off := pkt.hdr_desc.address & 16#3FF;
  own_hdr := false;
  if off <> 14 then begin
    eh := addr(ehdr);
    own_hdr := true;
  end
  else
    eh := hdr_view_ptr_t(pkt.hdr_desc.address & 16#FFFFFC00);

  { the destination }
  case pkt.link_addr.n_words of
    3: begin
      for i := 0 to 2 do
        eh^.words[i] := pkt.link_addr.addr[i];
    end;
    2: begin
      eh^.eth.dst.high := eth_apollo_high;
      eh^.eth.dst.low := link_view_ptr_t(addr(pkt.link_addr))^.node_low;
    end;
    otherwise begin
      status.all := status_$eth_illegal_dest_address;
      return;
    end;
  end;
  if (pkt.link_addr.n_words = 2)
     or else (eh^.eth.dst.high = eth_apollo_high) then begin
    node := eh^.eth.dst.low;
    ml_$lock(ml_$net_io_lock);
    ethernet_arp_resolve(u, node, eh^.eth.dst);
    ml_$unlock(ml_$net_io_lock);
  end;
  eh^.eth.src.addr := u^.station;
  eh^.eth.src.ptype := pkt.frame_type;

  { the pieces: the header, the data, the padding }
  list[1].va := eh;
  if own_hdr then begin
    list[1].len := 14;
    list[2].va := univ_ptr(pkt.hdr_desc.address);
    list[2].len := hlen;
    n := 2;
  end
  else begin
    list[1].len := 14 + hlen;
    n := 1;
  end;
  if pkt.data_length <> 0 then begin
    n := n + 1;
    mmu_$set_pmape(univ_ptr(u^.buf_va), u^.buf_pmape,
                   rshft(pkt.data_pages[1], 10));
    list[n].va := univ_ptr(u^.buf_va);
    list[n].len := dlen;
  end;
  if total < 60 then begin
    n := n + 1;
    list[n].va := addr(pad);
    list[n].len := 60 - total;
    total := 60;
  end;

  { the frame out }
  ml_$lock(ml_$net_io_lock);
  ethernet_transmit(u, addr(list), n, total, st);
  ml_$unlock(ml_$net_io_lock);
  status := st;
  if status.all = status_$eth_transmit_failed then
    with u^ do
      stats.counts[10] := stats.counts[10] + 1
  else if status.all <> status_$ok then
    with u^ do
      stats.counts[7] := stats.counts[7] + 1;

  { a frame for this unit too: loop a copy back }
  if (eh^.eth.dst = eh^.eth.src.addr) or else pkt.is_broadcast
     or else ethernet_mcast_listed(eh^.eth.dst, u^.mcast,
                                   u^.mcast_count) then begin
    src_va := 0;
    rpkt := mac_os_$rcv_pkt_t(pkt);
    hdr_page := pkt_$hdr_ptr_t(rpkt.body & 16#FFFFFC00);
    net_io_$copy_packet(hdr_page, off + rpkt.body_len, src_va, rpkt.data_pa,
                        rpkt.data_len, new_hdr, new_pages, st);
    if st.all = status_$ok then begin
      rpkt.body := off + new_hdr;
      rpkt.data_pa := new_pages;
      demux_flag := false;
      mac_os_$demux(rpkt, ethernet_port_array[u^.cnum], demux_flag, st);
      if st.all <> status_$ok then begin
        netbuf_$rtn_hdr(new_hdr);
        pkt_$dump_data(new_pages, rpkt.data_len);
      end;
    end;
  end;
end;
