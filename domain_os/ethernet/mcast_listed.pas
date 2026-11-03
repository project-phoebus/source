{ ethernet_mcast_listed - whether a multicast address is in a multicast
  list.

  Image addresses:
    sau8  0x03C8601E  ethernet_mcast_listed
    sau9  0x3C481C1E  ethernet_mcast_listed

  - An address without the group bit is not.  The list's entries are
    searched until n entries in use have been passed.

  Status stored: none.
}

function ethernet_mcast_listed(var addr: ethernet_$addr_t;
                               var list: ethernet_$mcast_list_t;
                               n: integer): boolean;
  internal;
var
  found: integer;
  i: integer;
begin
  if eth_addr_group in addr.first then begin
    found := 0;
    i := 1;
    while found < n do begin
      if list[i].addr = addr then begin
        ethernet_mcast_listed := true;
        return;
      end;
      if list[i].count > 0 then
        found := found + 1;
      i := i + 1;
    end;
  end;
  ethernet_mcast_listed := false;
end;
