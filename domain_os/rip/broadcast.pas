{ RIP_$BROADCAST - send the routing table of one routing to every port.

  Image addresses:
    sau2  0x00E87298  RIP_$BROADCAST

  - A response packet gets an entry for every route of the routing that
    is not empty and whose port routes for it, the hop count one more
    (at most 16 for the standard routing); if it has any, RIP_$SEND
    sends it to every port.

  Status stored: none.
}

{ TODO(pascal) RIP_$BROADCAST's frame: 0x18 bytes, three temporaries

  packet takes the top 0x220 bytes (8-aligned); the frame's three last
  longwords hold the compiler's three strength-reduced pointers to
  packet.entries[count], which dpc does not allocate; the
  slots of count, i, route and port take 12 of
  the 0x18 bytes between that nothing addresses, and 12 are left.  The
  stand-ins unused_240 (20 bytes, at a multiple of 8 from A6) and
  unused_244 (a longword) hold those and the temporaries' place, so that
  dpc's frame is the image's 0x244 bytes: one 24-byte object would be
  placed at a multiple of 8, where these bytes do not start. }

procedure rip_$broadcast(flags: boolean);
var
  packet: rip_$packet_t;
  count: integer;
  i: integer;
  route: rip_$route_ptr_t;
  port: route_$port_ptr_t;
  unused_240: array[1..5] of integer32;   { stand-in, see the TODO }
  unused_244: integer32;
begin
  packet.command := rip_cmd_response;
  count := 0;

  for i := 0 to 63 do begin
    if flags then
      route := addr(rip_$info[i].routes[1])
    else
      route := addr(rip_$info[i].routes[0]);
    if route^.flags.state <> rip_state_unused then begin
      port := addr(route_$port[route^.port]);
      if (flags and then (port^.active in [4, 5]))
         or else ((not flags) and then (port^.active in [3, 5])) then begin
        count := count + 1;
        packet.entries[count].network := rip_$info[i].network;
        if flags then
          packet.entries[count].metric := min(route^.metric + 1, 16)
        else
          packet.entries[count].metric := route^.metric + 1;
      end;
    end;
  end;

  if count <> 0 then
    rip_$send(rip_$dest_addr, -1, packet, count * 6 + 2, flags);
end;
