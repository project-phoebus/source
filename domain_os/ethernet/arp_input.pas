{ ethernet_arp_input - learn from a received packet's addresses, and
  answer ARP requests for this node.

  Image addresses:
    sau8  0x03C85B90  ethernet_arp_input
    sau9  0x3C481790  ethernet_arp_input

  Assume the packet is in the unit's header page (hdr), its source and
  type in rcv_src.

  - A Domain packet: its source node's entry gets the packet's source
    address, is made valid and gets a full lifetime.
  - An ARP packet of Ethernet and Domain addresses: a request for this
    node is answered; a reply updates the sender's entry the same way.

  Status stored: none.
}

{ TODO(pascal) the stand-in locals of ethernet_arp_input

  The routine's frame has 16 bytes more than its static-link slot and
  e, and no instruction addresses them.  unused_10 stands for whatever
  the original declared there (more `with' records or locals of the two
  arms). }

procedure ethernet_arp_input(u: ethernet_$unit_ptr_t; hdr: integer32);
  internal;
var
  e: integer32;
  unused_10: array[1..4] of integer32;    { stand-ins, see the TODO }
begin
  with ethernet_$rcv_hdr_ptr_t(hdr)^ do
    if u^.rcv_src.ptype = eth_type_domain then begin
      ml_$exclusion_start(u^.arp_lock);
      e := integer32(ethernet_arp_find(pkt.src_node, u^.arp));
      ethernet_$arp_entry_ptr_t(e)^.hw := u^.rcv_src.addr;
      ethernet_$arp_entry_ptr_t(e)^.state.valid := true;
      ethernet_$arp_entry_ptr_t(e)^.expire := time_$clockh + eth_arp_lifetime;
      ml_$exclusion_stop(u^.arp_lock);
    end
    else if u^.rcv_src.ptype = eth_type_arp then
      if (arp.hrd = arp_hrd_ethernet) and then (arp.pro = eth_type_domain) then
        if (arp.op = arp_op_request) and then (arp.tpa = node_$me) then
          ethernet_arp_reply(u, arp.spa, arp.sha)
        else if arp.op = arp_op_reply then begin
          ml_$exclusion_start(u^.arp_lock);
          e := integer32(ethernet_arp_find(arp.spa, u^.arp));
          ethernet_$arp_entry_ptr_t(e)^.hw := arp.sha;
          ethernet_$arp_entry_ptr_t(e)^.state.valid := true;
          ethernet_$arp_entry_ptr_t(e)^.expire :=
            time_$clockh + eth_arp_lifetime;
          ml_$exclusion_stop(u^.arp_lock);
        end;
end;
