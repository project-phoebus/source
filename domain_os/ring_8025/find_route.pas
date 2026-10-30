{ ring_8025_find_route - find or discover the route to a frame's
  destination.

  Image addresses:
    sau9  0x3C48630E  ring_8025_find_route

  - A group destination gets a single-route broadcast routing field.
  - A cached route is copied into the frame's routing field; an expired
    one is copied too, and its station's low half is cleared so that it
    is not found again.
  - Otherwise, on the first try, this node and a station that answers an
    XID sent without a routing field (its address recognized) are
    learned as on this ring.  Then an XID is broadcast on a single route
    and the route eventcount awaited for 4 ticks; a learned route sends
    the search back to the cache, a time-out sends another XID, 3 tries
    in all.  A station not found is sent to without a routing field.
  - dsap, ssap and ctl, the frame's LLC header, are not used.
  - rif_len returns the routing field's length (0: none).

  Status stored: none.
}

procedure ring_8025_find_route(u: ring_8025_$unit_ptr_t;
                               var hdr: ring_8025_$mac_hdr_t;
                               dsap: integer; ssap: integer; ctl: integer;
                               out rif_len: integer);
  internal;
var
  ecs: array[1..2] of ec_$eventcount_ptr_t;
  vals: array[1..2] of integer32;
  status: status_$t;
  fstat: integer;
  bucket: integer;
  tries: integer;
  i: integer;
  j: integer;
begin
  if hdr.dest.group then begin
    hdr.rif.rc_word := r8025_rc_single_bcast;
    rif_len := 2;
    return;
  end;
  tries := 0;
  bucket := hdr.dest.low & 16#3F;
  repeat

    { the destination's cached route }
    ml_$exclusion_start(u^.route_lock);
    for i := 0 to r8025_route_ways do
      with ring8025_$aux_da.routes[u^.cnum, bucket, i] do
        if (hdr.dest.high = station.high) and then
           (hdr.dest.low = station.low) then begin
          if rif.rc.len <> 0 then
            for j := 1 to rif.rc.len do
              hdr.rif.bytes[j] := rif.bytes[j];
          if time_$clockh_ec.value > expiry then
            station.low := 0;
          rif_len := rif.rc.len;
          ml_$exclusion_stop(u^.route_lock);
          return;
        end;
    ml_$exclusion_stop(u^.route_lock);

    { not cached: ask the station }
    repeat
      if tries = 0 then begin
        if (hdr.dest.high = r8025_addr_high) and then
           (hdr.dest.low = node_$me) then begin
          ring_8025_learn_local(u, hdr.dest);
          rif_len := 0;
          return;
        end;
        ring_8025_send_xid(u, hdr.dest, 0, r8025_null_sap, r8025_xid_ssap,
                           r8025_llc_xid, fstat, status);
        if (status.all = status_$ok) and then
           ((fstat & r8025_fs_recognized) = r8025_fs_recognized) then begin
          ring_8025_learn_local(u, hdr.dest);
          rif_len := 0;
          return;
        end;
      end;
      tries := tries + 1;
      ring_8025_send_xid(u, hdr.dest, r8025_rc_single_bcast, r8025_null_sap,
                         r8025_xid_ssap, r8025_llc_xid, fstat, status);
      ecs[1] := addr(u^.route_ec);
      vals[1] := u^.route_wait_val;
      ecs[2] := addr(time_$clockh_ec);
      vals[2] := ec_$read(time_$clockh_ec) + r8025_xid_wait;
      case ec_$waitn(ecs, vals, 2) of
        1: exit;
        2: if tries >= r8025_xid_tries then begin
             rif_len := 0;
             return;
           end;
      end;
    until false;
  until tries >= r8025_xid_tries;
  rif_len := 0;
end;
