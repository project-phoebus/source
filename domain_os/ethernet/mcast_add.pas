{ ethernet_mcast_add - find or make a multicast list's entry for an
  address.

  Image addresses:
    sau8  0x03C8606A  ethernet_mcast_add
    sau9  0x3C481C6A  ethernet_mcast_add

  - The address must have the group bit and not be one of Apollo's two
    multicast addresses.  An entry with the address already is found
    while n entries in use are passed; else the first free entry passed,
    or the one after the last passed, gets the address (its count is
    the caller's to set).
  - The result is the entry's index, 0 on an error.

  Status stored:
    status_$ok: the entry was found or made
    status_$eth_not_multicast: the address has no group bit
    status_$eth_is_multicast: the address is Apollo's
    status_$eth_multicast_list_full: there is no entry left
}

function ethernet_mcast_add(var addr: ethernet_$addr_t;
                            var list: ethernet_$mcast_list_t; n: integer;
                            out status: status_$t): integer;
  internal;
var
  found: integer;
  i: integer;
  free: integer;
begin
  if not (eth_addr_group in addr.first) then begin
    status.all := status_$eth_not_multicast;
    ethernet_mcast_add := 0;
    return;
  end;
  if (addr.high = eth_apollo_mcast_high)
     and then ((addr.low = 0) or else (addr.low = 1)) then begin
    status.all := status_$eth_is_multicast;
    ethernet_mcast_add := 0;
    return;
  end;
  found := 0;
  i := 1;
  free := 0;
  while found < n do begin
    if list[i].addr = addr then begin
      status.all := status_$ok;
      ethernet_mcast_add := i;
      return;
    end;
    if list[i].count > 0 then
      found := found + 1
    else if free = 0 then
      free := i;
    i := i + 1;
  end;
  if free <> 0 then
    i := free;
  if i <= 15 then begin
    list[i].addr := addr;
    status.all := status_$ok;
    ethernet_mcast_add := i;
  end
  else begin
    status.all := status_$eth_multicast_list_full;
    ethernet_mcast_add := 0;
  end;
end;
