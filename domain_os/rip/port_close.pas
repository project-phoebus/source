{ RIP_$PORT_CLOSE - expire the routes through a closing port.

  Image addresses:
    sau2  0x00E15798  RIP_$PORT_CLOSE

  - Under the RIP lock each route of the given routing that goes through
    the port (unless forced, not a direct one) becomes unreachable and
    expired, its time restarted and the change flagged.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes of RIP_$PORT_CLOSE hold nothing

  Nothing addresses the frame; i's and route's slots take 8 of its 12
  bytes.  The stand-in unused_c holds the 4. }

procedure rip_$port_close(port_index: integer; std: boolean; force: boolean);
var
  i: integer;
  route: rip_$route_ptr_t;
  unused_c: integer32;                    { stand-in, see the TODO }
begin
  rip_$lock;

  for i := 0 to 63 do begin
    if std then
      route := addr(rip_$info[i].routes[1])
    else
      route := addr(rip_$info[i].routes[0]);
    if (route^.flags.state <> rip_state_unused)
       and then (route^.port = port_index)
       and then (force or else (route^.metric <> 0)) then begin
      route^.metric := rip_infinity;
      route^.flags.state := rip_state_expired;
      route^.expiration := time_$clockh + rip_route_timeout;
      if std then
        rip_$std_recent_changes := true
      else
        rip_$recent_changes := true;
    end;
  end;

  rip_$unlock;
end;
