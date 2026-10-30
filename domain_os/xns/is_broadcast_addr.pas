{ xns_$is_broadcast_addr - whether an XNS address is the broadcast host
  or one of this node's.

  Image addresses:
    sau2  0x00E17E88  xns_$is_broadcast_addr

  - True when the host's three words are all 16#FFFF, or the network is
    a routing port's and the host one of the registered addresses.

  Status stored: none.
}

function xns_$is_broadcast_addr(in addr: xns_$addr_t): boolean; internal;
var
  p: integer;                             { the loop's }
  i: integer;                             { the loop's }
  unused_c: integer32;                    { stand-in }
begin
  xns_$is_broadcast_addr := false;
  if (addr.host[2] = 16#FFFF) and then (addr.host[0] = 16#FFFF)
     and then (addr.host[1] = 16#FFFF) then begin
    xns_$is_broadcast_addr := true;
    return;
  end;

  for p := 0 to xns_max_ports - 1 do
    if xns_idp_$port_table[p].net_addr_ptr^.network = addr.network then
      for i := 0 to xns_idp_$registered_count do
        if (xns_idp_$addrs[i][2] = addr.host[2])
           and then (xns_idp_$addrs[i][1] = addr.host[1])
           and then (xns_idp_$addrs[i][0] = addr.host[0]) then begin
          xns_$is_broadcast_addr := true;
          return;
        end;
end;
