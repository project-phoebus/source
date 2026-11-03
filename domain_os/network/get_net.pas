{ NETWORK_$GET_NET - the network an address's index names.

  Image addresses:
    sau2  0x00E0F2CC  NETWORK_$GET_NET
    sau8  0x03C10616  NETWORK_$GET_NET

  - Index 0 is this node's own network and gives network 0; otherwise
    the entry's network.

  Status stored:
    status_$ok: the network was returned
    status_$network_unknown_network: the entry has none (network 0)
}

procedure network_$get_net(addr: network_$net_addr_t; out net_id: integer32;
                           out status: status_$t);
label
  20;
begin
  if addr.net_index = 0 then
    net_id := 0
  else begin
    if network_$net_table[addr.net_index].net_id = 0 then goto 20;
    net_id := network_$net_table[addr.net_index].net_id;
  end;

  status.all := status_$ok;
  return;

  { no such network }
20:
  net_id := 0;
  status.all := status_$network_unknown_network;
end;
