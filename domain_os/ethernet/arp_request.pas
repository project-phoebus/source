{ ethernet_arp_request - ask for a node's Ethernet address.

  Image addresses:
    sau8  0x03C8597E  ethernet_arp_request
    sau9  0x3C48157E  ethernet_arp_request

  - An ARP request for the node, from this unit's address and node ID,
    to Apollo's second multicast address, padded to 60 bytes.
  - A failed transmit is counted (the tenth count), another error the
    seventh.

  Status stored: none.
}

procedure ethernet_arp_request(u: ethernet_$unit_ptr_t; node: linteger);
  internal;
var
  list: array[1..2] of ethernet_$xmit_piece_t;
  pad: array[1..24] of char;
  unused_2a: array[1..6] of char;
  pkt: ethernet_$arp_pkt_t;
  status: status_$t;
begin
  pkt.dst.high := eth_apollo_mcast_high;
  pkt.dst.low := 1;
  pkt.src := u^.station;
  pkt.etype := eth_type_arp;
  pkt.hrd := arp_hrd_ethernet;
  pkt.pro := eth_type_domain;
  pkt.hln := 6;
  pkt.pln := 4;
  pkt.op := arp_op_request;
  pkt.sha := u^.station;
  pkt.spa := node_$me;
  pkt.tpa := node;
  list[1].va := addr(pkt);
  list[1].len := 42;
  list[2].va := addr(pad);
  list[2].len := 18;
  ethernet_transmit(u, addr(list), 2, 60, status);
  if status.all = status_$eth_transmit_failed then
    u^.stats.counts[10] := u^.stats.counts[10] + 1
  else if status.all <> status_$ok then
    u^.stats.counts[7] := u^.stats.counts[7] + 1;
end;
