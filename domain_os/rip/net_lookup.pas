{ RIP_$NET_LOOKUP - the routing table entry of a network.

  Image addresses:
    sau2  0x00E154E4  RIP_$NET_LOOKUP

  - The table is a hash of 64 entries, probed linearly from the
    network's low six bits.  The result is the network's entry, else 0.
  - Asked to, a found entry's packet is counted; not found and asked to
    create, the first entry with both routes empty or expired is taken.

  Status stored: none.
}

{ TODO(pascal) 8 frame bytes of RIP_$NET_LOOKUP hold nothing

  The slots of the three register-held words (6 bytes) and the 4-byte
  result variable account for 12 of the frame's 20 bytes; nothing
  addresses the frame at all.  A 4-byte pointer local and a word would
  fill the 8 bytes by size, but the image's element operands do not fit
  a pointer local.  The stand-ins unused_10 and unused_14, two
  longwords, hold the place: the bytes do not start at a multiple of 8
  from A6, where an 8-byte object would be placed. }

function rip_$net_lookup(network: integer32; inc_refcount: boolean;
                         create: boolean): integer32;
var
  start_idx: integer;
  idx: integer;
  free_idx: integer;
  unused_10: integer32;                   { stand-in, see the TODO }
  unused_14: integer32;
begin
  idx := network & 16#3F;
  free_idx := -1;
  start_idx := idx;

  repeat
    if network = rip_$info[idx].network then begin
      if inc_refcount then
        rip_$stats.net_pkts[idx] := rip_$stats.net_pkts[idx] + 1;
      rip_$net_lookup := integer32(addr(rip_$info[idx]));
      return;
    end;
    if (free_idx = -1)
       and then ((rip_$info[idx].routes[0].flags.state = rip_state_unused)
                 or else (rip_$info[idx].routes[0].flags.state
                          = rip_state_expired))
       and then ((rip_$info[idx].routes[1].flags.state = rip_state_unused)
                 or else (rip_$info[idx].routes[1].flags.state
                          = rip_state_expired)) then
      free_idx := idx;
    idx := (idx + 1) & 16#3F;
  until idx = start_idx;

  if create and then (free_idx <> -1) then begin
    rip_$info[free_idx].network := network;
    rip_$info[free_idx].routes[0].flags.state := rip_state_expired;
    rip_$info[free_idx].routes[1].flags.state := rip_state_expired;
    rip_$net_lookup := integer32(addr(rip_$info[free_idx]));
    if inc_refcount then
      rip_$stats.net_pkts[free_idx] := 0
    else
      rip_$stats.net_pkts[free_idx] := 1;
  end
  else
    rip_$net_lookup := 0;
end;
