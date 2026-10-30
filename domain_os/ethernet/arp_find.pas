{ ethernet_arp_find - find a node's entry in the ARP cache, or make one.

  Image addresses:
    sau9  0x3C481706  ethernet_arp_find

  - The node's row is that of its low six bits.  A node not in the row
    takes the entry that expires first, given the node's default
    Ethernet address (Apollo's block and the node ID's low 24 bits), not
    valid, no requests sent, and a full lifetime.
  - The result is the entry's address.

  Status stored: none.
}

function ethernet_arp_find(id: linteger; var arp: ethernet_$arp_table_t):
  ethernet_$arp_entry_ptr_t;
  internal;
var
  h: integer;
  j: integer;
  best: integer;
  oldest: time_$clockh_t;
  e: ethernet_$arp_entry_ptr_t;
begin
  h := id & 16#3F;
  best := 0;
  oldest := arp[h, 0].expire;
  for j := 0 to 3 do
    with arp[h, j] do begin
      if node = id then begin
        ethernet_arp_find := addr(arp[h, j]);
        return;
      end;
      if expire < oldest then begin
        best := j;
        oldest := expire;
      end;
    end;
  e := addr(arp[h, best]);
  ethernet_arp_find := e;
  with e^ do begin
    node := id;
    hw.high := eth_apollo_high;
    hw.low := id;
    state.tries := 0;
    state.valid := false;
    expire := time_$clockh + eth_arp_lifetime;
  end;
end;
