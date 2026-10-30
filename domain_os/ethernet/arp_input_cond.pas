{ ethernet_arp_input_cond - learn from a received packet's addresses, at
  interrupt level.

  Image addresses:
    sau9  0x3C484264  ethernet_arp_input_cond

  Assume the packet is in the unit's header page (hdr), its source and
  type in rcv_src.

  - ethernet_arp_input where it can be done without waiting: the ARP
    cache is updated only if its lock is free.
  - The result is false when the packet must be seen at process level:
    the ARP lock was held, or it is an ARP request for this node (the
    reply is sent from there).

  Status stored: none.
}

function ethernet_arp_input_cond(u: ethernet_$unit_ptr_t; hdr: integer32):
  boolean;
  internal;
var
  e: integer32;
begin
  with ethernet_$rcv_hdr_ptr_t(hdr)^ do
    if u^.rcv_src.ptype = eth_type_domain then begin
      if ml_$cond_exclusion_start(u^.arp_lock) then begin
        ethernet_arp_input_cond := false;
        return;
      end;
      e := integer32(ethernet_arp_find(pkt.src_node, u^.arp));
      ethernet_$arp_entry_ptr_t(e)^.hw := u^.rcv_src.addr;
      ethernet_$arp_entry_ptr_t(e)^.state.valid := true;
      ethernet_$arp_entry_ptr_t(e)^.expire := time_$clockh + eth_arp_lifetime;
      ml_$cond_exclusion_stop(u^.arp_lock);
    end
    else if u^.rcv_src.ptype = eth_type_arp then
      if (arp.hrd = arp_hrd_ethernet) and then (arp.pro = eth_type_domain) then
        if (arp.op = arp_op_request) and then (arp.tpa = node_$me) then begin
          ethernet_arp_input_cond := false;
          return;
        end
        else if arp.op = arp_op_reply then begin
          if ml_$cond_exclusion_start(u^.arp_lock) then begin
            ethernet_arp_input_cond := false;
            return;
          end;
          e := integer32(ethernet_arp_find(arp.spa, u^.arp));
          ethernet_$arp_entry_ptr_t(e)^.hw := arp.sha;
          ethernet_$arp_entry_ptr_t(e)^.state.valid := true;
          ethernet_$arp_entry_ptr_t(e)^.expire :=
            time_$clockh + eth_arp_lifetime;
          ml_$cond_exclusion_stop(u^.arp_lock);
        end;
  ethernet_arp_input_cond := true;
end;
