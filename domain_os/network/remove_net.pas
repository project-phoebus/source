{ NETWORK_$REMOVE_NET - give back a network's entry in the network table.

  Image addresses:
    sau2  0x00E0F27C  NETWORK_$REMOVE_NET

  - An address with index 0 (this node's network) needs nothing.
    Otherwise the entry's reference count is lowered, and the entry
    freed (its network cleared) when it reaches zero.

  Status stored:
    status_$ok: the entry was given back, or none was needed
    status_$network_unknown_network: the entry has no network
}

procedure network_$remove_net(addr: network_$net_addr_t;
                              out status: status_$t);
label
  20;
begin
  if addr.net_index <> 0 then begin
    if network_$net_table[addr.net_index].net_id = 0 then goto 20;
    network_$net_table[addr.net_index].refcount :=
      network_$net_table[addr.net_index].refcount - 1;
    if network_$net_table[addr.net_index].refcount = 0 then
      network_$net_table[addr.net_index].net_id := 0;
  end;

  status.all := status_$ok;
  return;

  { no such network }
20:
  status.all := status_$network_unknown_network;
end;
