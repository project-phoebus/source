{ RIP_$HALT_ROUTER - tell every port that this node no longer routes.

  Image addresses:
    sau2  0x00E87396  RIP_$HALT_ROUTER

  - RIP_$SEND sends the module's halt record (network -1 at 16 hops) to
    every port of the routing, and that routing's change flag is
    cleared.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes of RIP_$HALT_ROUTER hold nothing

  A 4-byte frame in a global routine with no locals and no result
  (RIP_$SEND_UPDATES, of the same shape, has none): the 4 bytes are the
  reserved slot of a routine that is not a global symbol, but the map names
  this one; FIND_VOLX has the same open question.  The
  stand-in unused_4 holds them. }

procedure rip_$halt_router(flags: boolean);
var
  unused_4: integer32;                    { stand-in, see the TODO }
begin
  if flags then begin
    rip_$send(rip_$dest_addr, -1, rip_$halt_data, 8, true);
    rip_$std_recent_changes := false;
  end
  else begin
    rip_$send(rip_$dest_addr, -1, rip_$halt_data, 8, false);
    rip_$recent_changes := false;
  end;
end;
