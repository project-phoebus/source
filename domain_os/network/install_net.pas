{ NETWORK_$INSTALL_NET - enter a network in the network table.

  Image addresses:
    sau2  0x00E0F1E0  NETWORK_$INSTALL_NET
    sau8  0x03C10534  NETWORK_$INSTALL_NET

  - A zero network is this node's own: the address's index is cleared.
    Otherwise the network's entry (of 64) gets its index into the
    address and its reference count raised, or a free entry takes it.
  - The index is merged unmasked from its byte.

  Status stored:
    status_$ok: the network was entered
    status_$network_too_many_networks_in_internet: no free entry (the
      index cleared)
}

{ TODO(pascal) 4 frame bytes of NETWORK_$INSTALL_NET no local explains

  The frame has 8 bytes: i and free, two words, need 4 (dpc's
  `--dump-locals': free -0x2, i -0x4, frame 4); no instruction addresses
  the frame.  NETWORK_$INIT's `for' loop leaves 2 bytes over its locals
  too (14 rounded to 0x10), which a 2-byte hidden slot per `for' loop
  would explain in both (not settled, the five routines cited there show
  none). }

procedure network_$install_net(net: integer32;
                               in out addr: network_$net_addr_t;
                               out status: status_$t);
label
  10, 20;
var
  free: pinteger;
  i: pinteger;
begin
  { this node's own network }
  if net = 0 then
    addr.net_index := 0
  else begin
    { the network's entry, or the first free }
    free := 0;
    for i := 1 to 64 do begin
      if network_$net_table[i].net_id = net then begin
        addr.net_index := i;
        network_$net_table[i].refcount :=
          network_$net_table[i].refcount + 1;
        goto 10;
      end;
      if (network_$net_table[i].net_id = 0) and then (free = 0) then
        free := i;
    end;

    { a new entry }
    if free = 0 then goto 20;
    addr.net_index := free;
    network_$net_table[free].net_id := net;
    network_$net_table[free].refcount := 1;
  end;

10:
  status.all := status_$ok;
  return;

  { the table is full }
20:
  addr.net_index := 0;
  status.all := status_$network_too_many_networks_in_internet;
end;
