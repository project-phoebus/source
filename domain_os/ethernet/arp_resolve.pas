{ ethernet_arp_resolve - the Ethernet address to send a node's packets to.

  Image addresses:
    sau9  0x3C48187C  ethernet_arp_resolve

  - The node's ARP cache entry (made if it has none) gives the address.
    A valid entry that has expired is made not valid, with a new
    lifetime; while an entry is not valid an ARP request goes out for
    it on each call, 20 at most in a lifetime.  Until a reply comes the
    entry's address is the node's default.

  Status stored: none.
}

procedure ethernet_arp_resolve(u: ethernet_$unit_ptr_t; var node: linteger;
                               out hw: ethernet_$addr_t);
  internal;
var
  e: ethernet_$arp_entry_ptr_t;
begin
  ml_$exclusion_start(u^.arp_lock);
  e := ethernet_arp_find(node, u^.arp);
  if e^.state.valid then begin
    if integer32(time_$clockh) > e^.expire then begin
      e^.state.tries := 0;
      e^.state.valid := false;
      e^.expire := time_$clockh + eth_arp_lifetime;
    end;
  end
  else begin
    if (e^.state.tries >= eth_arp_max_tries)
       and then (integer32(time_$clockh) > e^.expire) then begin
      e^.state.tries := 0;
      e^.expire := time_$clockh + eth_arp_lifetime;
    end;
    if e^.state.tries < eth_arp_max_tries then begin
      ethernet_arp_request(u, node);
      e^.state.tries := e^.state.tries + 1;
    end;
  end;
  hw := e^.hw;
  ml_$exclusion_stop(u^.arp_lock);
end;
