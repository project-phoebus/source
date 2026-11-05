{ ETHERNET_$SEND - send a Domain packet.

  Image addresses:
    sau6  0x780889CE  ETHERNET_$SEND
    sau7  0x3C4930C4  ETHERNET_$SEND
    sau8  0x03C868C0  ETHERNET_$SEND
    sau9  0x3C4824C0  ETHERNET_$SEND

  - The driver record's sendp entry.  The packet goes out as an Ethernet
    header, an IDP header, the Domain header and the data, each part's
    length rounded up to even and the whole padded to the Ethernet's
    least of 60 bytes.
  - A broadcast goes to Apollo's multicast address, another packet to
    its node's Ethernet address (ethernet_arp_resolve).  An internet
    packet (routing type above 1) carries the IDP header its Domain
    header holds; a local one gets a header of its own.
  - Data given by page only is mapped through the unit's first buffer
    page.  A failed transmit counts in eth_stat_xmit_failed, another
    failure in eth_stat_errors.
  - With `ethernet_vme': only the Domain header's length is rounded up;
    every piece is copied into the transmit buffer (its physical address
    eth_vme_dma_limit), the data page mapped with NETBUF_$GETVA for the
    copy and given back after it.

  Status stored:
    status_$eth_invalid_unit_num: socket is not unit 0 or 1
    status_$eth_device_offline: the unit does not take Domain packets
    status_$eth_illegal_pkt_length: the packet is longer than 1514 bytes
    ethernet_transmit's status: otherwise
}

%if ethernet_vme %then
procedure ethernet_$send(var socket: pinteger; hdr_pa: integer32;
                         hdr: ethernet_$xmit_hdr_ptr_t; hdr_len: integer;
                         in data_pages: univ pkt_$data_pages_t;
                         data_va: integer32; data_len: pinteger;
                         in flags: univ integer;
                         out xmit_status: pinteger;
                         out status_ret: status_$t);
  options(val_param);
var
  pas: ethernet_$xmit_pa_list_t;
  pad: array[1..46] of char;
  idp: ethernet_$idp_t;
  eth: ethernet_$eth_hdr_t;
  pieces: array[1..5] of ethernet_$xmit_piece_t;
  u: ethernet_$unit_ptr_t;
  hlen: pinteger;
  total: pinteger;
  count: integer;
begin
  xmit_status := 0;
  if socket > eth_max_unit then begin
    status_ret.all := status_$eth_invalid_unit_num;
    return;
  end;
  u := addr(ether_ucb[socket]);
  if not (eth_unit_domain in u^.flags) then begin
    status_ret.all := status_$eth_device_offline;
    return;
  end;
  hlen := hdr_len;
  hlen := (hlen + 1) & ~1;
  total := hlen + data_len + 44;
  if total > 1514 then begin
    status_ret.all := status_$eth_illegal_pkt_length;
    return;
  end;

  { the Ethernet header }
  if pkt_$hdr_broadcast in hdr^.pkt.flag_bits.info_bits then begin
    eth.dst.high := eth_apollo_mcast_high;
    eth.dst.low := 0;
  end
  else
    ethernet_arp_resolve(u, hdr^.pkt.dest_node, eth.dst);
  eth.src.addr := u^.station;
  eth.src.ptype := eth_type_domain;
  pieces[1].va := addr(eth);
  pieces[1].len := 14;
  pas[1] := eth_vme_dma_limit;

  { the IDP header }
  if hdr^.pkt.routing_type > 1 then begin
    idp := hdr^.idp;
    idp.packet_type := eth_idp_type_domain;
    idp.dest_host := eth.dst;
    idp.src_host := eth.src.addr;
  end
  else begin
    idp.checksum := 16#FFFF;
    idp.length := total - 14;
    idp.transport_ctl := 0;
    idp.packet_type := eth_idp_type_domain;
    idp.dest_net := 0;
    idp.dest_host := eth.dst;
    idp.dest_sock := 0;
    idp.src_net := 0;
    idp.src_host := eth.src.addr;
    idp.src_sock := hdr^.pkt.src_sock;
  end;
  pieces[2].va := addr(idp);
  pieces[2].len := 30;
  pas[2] := eth_vme_dma_limit;

  { the Domain header and the data }
  pieces[3].va := hdr;
  pieces[3].len := hlen;
  pas[3] := eth_vme_dma_limit;
  count := 3;
  if data_len <> 0 then begin
    count := 4;
    if data_va = 0 then begin
      netbuf_$getva(data_pages[1], u^.xmit_map_va, status_ret);
      ethernet_check_status(status_ret);
      pieces[4].va := univ_ptr(u^.xmit_map_va);
    end
    else
      pieces[4].va := univ_ptr(data_va);
    pieces[4].len := data_len;
    pas[4] := eth_vme_dma_limit;
  end;

  { the padding }
  if total < 60 then begin
    count := count + 1;
    pieces[count].va := addr(pad);
    pieces[count].len := 60 - total;
    pas[count] := eth_vme_dma_limit;
    total := 60;
  end;

  ethernet_transmit(u, ethernet_$xmit_list_ptr_t(addr(pieces)), count,
                    addr(pas), total, 0, status_ret);
  if data_len <> 0 then
    if data_va = 0 then
      discard(netbuf_$rtnva(u^.xmit_map_va));
  if status_ret.all = status_$eth_transmit_failed then
    with u^ do
      stats.counts[eth_stat_xmit_failed] :=
        stats.counts[eth_stat_xmit_failed] + 1
  else if status_ret.all <> status_$ok then
    with u^ do
      stats.counts[eth_stat_errors] := stats.counts[eth_stat_errors] + 1;
end;
%else
procedure ethernet_$send(var socket: pinteger; hdr_pa: integer32;
                         hdr: ethernet_$xmit_hdr_ptr_t; hdr_len: integer;
                         in data_pages: univ pkt_$data_pages_t;
                         data_va: integer32; data_len: pinteger;
                         in flags: univ integer;
                         out xmit_status: pinteger;
                         out status_ret: status_$t);
  options(val_param);
var
  pad: array[1..46] of char;
  idp: ethernet_$idp_t;
  eth: ethernet_$eth_hdr_t;
  pieces: array[1..5] of ethernet_$xmit_piece_t;
  u: ethernet_$unit_ptr_t;
  hlen: integer;
  dlen: integer;
  total: integer;
  count: integer;
begin
  xmit_status := 0;
  if socket > eth_max_unit then begin
    status_ret.all := status_$eth_invalid_unit_num;
    return;
  end;
  u := addr(ether_ucb[socket]);
  if not (eth_unit_domain in u^.flags) then begin
    status_ret.all := status_$eth_device_offline;
    return;
  end;
  hlen := hdr_len;
  dlen := data_len;
  hlen := (hlen + 1) & ~1;
  dlen := (dlen + 1) & ~1;
  total := hlen + dlen + 44;
  if total > 1514 then begin
    status_ret.all := status_$eth_illegal_pkt_length;
    return;
  end;

  { the Ethernet header }
  if pkt_$hdr_broadcast in hdr^.pkt.flag_bits.info_bits then begin
    eth.dst.high := eth_apollo_mcast_high;
    eth.dst.low := 0;
  end
  else
    ethernet_arp_resolve(u, hdr^.pkt.dest_node, eth.dst);
  eth.src.addr := u^.station;
  eth.src.ptype := eth_type_domain;
  pieces[1].va := addr(eth);
  pieces[1].len := 14;

  { the IDP header }
  if hdr^.pkt.routing_type > 1 then begin
    idp := hdr^.idp;
    idp.packet_type := eth_idp_type_domain;
    idp.dest_host := eth.dst;
    idp.src_host := eth.src.addr;
  end
  else begin
    idp.checksum := 16#FFFF;
    idp.length := total - 14;
    idp.transport_ctl := 0;
    idp.packet_type := eth_idp_type_domain;
    idp.dest_net := 0;
    idp.dest_host := eth.dst;
    idp.dest_sock := 0;
    idp.src_net := 0;
    idp.src_host := eth.src.addr;
    idp.src_sock := hdr^.pkt.src_sock;
  end;
  pieces[2].va := addr(idp);
  pieces[2].len := 30;

  { the Domain header and the data }
  pieces[3].va := hdr;
  pieces[3].len := hlen;
  count := 3;
  if data_len <> 0 then begin
    count := 4;
    if data_va = 0 then begin
      mmu_$set_pmape(univ_ptr(u^.buf_va), u^.buf_pmape,
                     rshft(data_pages[1], 10));
      pieces[4].va := univ_ptr(u^.buf_va);
    end
    else
      pieces[4].va := univ_ptr(data_va);
    pieces[4].len := dlen;
  end;

  { the padding }
  if total < 60 then begin
    count := count + 1;
    pieces[count].va := addr(pad);
    pieces[count].len := 60 - total;
    total := 60;
  end;

  ethernet_transmit(u, ethernet_$xmit_list_ptr_t(addr(pieces)), count, total,
                    status_ret);
  if status_ret.all = status_$eth_transmit_failed then
    with u^ do
      stats.counts[eth_stat_xmit_failed] :=
        stats.counts[eth_stat_xmit_failed] + 1
  else if status_ret.all <> status_$ok then
    with u^ do
      stats.counts[eth_stat_errors] := stats.counts[eth_stat_errors] + 1;
end;
%endif
