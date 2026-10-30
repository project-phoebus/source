{ RIP_$AGE - age the routing table's routes.

  Image addresses:
    sau2  0x00E155C0  RIP_$AGE

  - Under the RIP lock every route whose time has come moves on: a valid
    route ages, an aging one expires (its hop count unreachable, the
    change flagged), an expired one is emptied.
  - Then RIP's updates are sent for the Domain internet and for the
    standard routing (RIP_$SEND_UPDATES).

  Status stored: none.
}

{ TODO(pascal) 8 frame bytes of RIP_$AGE hold nothing

  Nothing addresses the frame; the five register-held locals' slots
  take 12 of its 20 bytes.  TIME_$CLOCKH's
  hoisted address is the compiler's.  The stand-ins unused_10 and
  unused_14, two longwords, hold the other 8: the bytes do not start at
  a multiple of 8 from A6, where an object of 8 bytes or more is placed,
  so the original's objects there were smaller. }

procedure rip_$age;
var
  i: integer;
  j: integer;
  route: rip_$route_ptr_t;
  state: integer;
  is_std: boolean;
  unused_10: integer32;                   { stand-ins, see the TODO }
  unused_14: integer32;
begin
  rip_$lock;

  for i := 0 to 63 do
    for j := 0 to 1 do begin
      if j = 0 then begin
        is_std := true;
        route := addr(rip_$info[i].routes[1]);
      end
      else begin
        is_std := false;
        route := addr(rip_$info[i].routes[0]);
      end;
      state := route^.flags.state;
      if (state <> rip_state_unused)
         and then (time_$clockh > route^.expiration) then
        case state of
          rip_state_valid: begin
            if route^.metric <> 0 then begin
              route^.expiration := time_$clockh + rip_route_timeout;
              route^.flags.state := rip_state_aging;
            end;
          end;
          rip_state_aging: begin
            route^.metric := rip_infinity;
            if is_std then
              rip_$std_recent_changes := true
            else
              rip_$recent_changes := true;
            route^.expiration := time_$clockh + rip_route_timeout;
            route^.flags.state := rip_state_expired;
          end;
          otherwise begin
            route^.flags.state := rip_state_unused;
          end;
        end;
    end;

  rip_$unlock;
  rip_$send_updates(false);
  rip_$send_updates(true);
end;
