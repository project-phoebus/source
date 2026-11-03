{ ring_8025_learn_route - learn the route to a frame's source station.

  Image addresses:
    sau8  0x03C8A48E  ring_8025_learn_route
    sau9  0x3C486092  ring_8025_learn_route

  - The station's bucket is chosen by the low six bits of its address.
    The source's routing indicator is cleared in the frame's header.
  - A station already cached: a frame from this ring (a routing field
    of only its control word) makes it local; another frame's route
    replaces the cached one when it is shorter and carries a largest
    frame the unit's frames fit in.  The route eventcount is advanced.
  - A station not cached takes the bucket's route that expires first,
    under the same conditions but whatever the length; the eventcount
    is advanced only when it is taken.
  - A stored route has its direction reversed and is not a broadcast;
    it expires r8025_route_life TIME_$CLOCKH units from now.

  Status stored: none.
}

procedure ring_8025_learn_route(u: ring_8025_$unit_ptr_t;
                                var hdr: ring_8025_$mac_hdr_t);
  internal;
var
  oldest_time: time_$clockh_t;
  bucket: integer;
  oldest: integer;
  i: integer;
  j: integer;
  ok: boolean;
begin
  oldest := 0;
  bucket := hdr.src.low & 16#3F;
  oldest_time := ring8025_$aux_da.routes[u^.cnum, bucket, 0].expiry;
  hdr.src.rii := false;
  ml_$exclusion_start(u^.route_lock);

  { the station's cached route, if any }
  for i := 0 to r8025_route_ways do
    with ring8025_$aux_da.routes[u^.cnum, bucket, i] do begin
      if (hdr.src.high = station.high) and then
         (hdr.src.low = station.low) then begin
        if hdr.rif.rc.len = 2 then begin
          rif.rc.len := 0;
          expiry := time_$clockh + r8025_route_life;
        end
        else if (ring_8025_lf_size[hdr.rif.rc.lf] >= u^.max_frame - 14)
                and then (hdr.rif.rc.len < rif.rc.len) then begin
          for j := 1 to hdr.rif.rc.len do
            rif.bytes[j] := hdr.rif.bytes[j];
          rif.rc.dir := not rif.rc.dir;
          rif.rc.bcast := false;
          expiry := time_$clockh + r8025_route_life;
        end;
        ec_$advance(u^.route_ec);
        u^.route_wait_val := ec_$read(u^.route_ec) + 1;
        ml_$exclusion_stop(u^.route_lock);
        return;
      end;
      if oldest_time > expiry then begin
        oldest := i;
        oldest_time := expiry;
      end;
    end;

  { a new station: in place of the route that expires first }
  with ring8025_$aux_da.routes[u^.cnum, bucket, oldest] do begin
    ok := false;
    if hdr.rif.rc.len = 2 then begin
      rif.rc.len := 0;
      ok := true;
    end
    else if ring_8025_lf_size[hdr.rif.rc.lf] >= u^.max_frame - 14 then begin
      for j := 1 to hdr.rif.rc.len do
        rif.bytes[j] := hdr.rif.bytes[j];
      rif.rc.dir := not rif.rc.dir;
      rif.rc.bcast := false;
      ok := true;
    end;
    if ok then begin
      station.high := hdr.src.high;
      station.low := hdr.src.low;
      expiry := time_$clockh + r8025_route_life;
      ec_$advance(u^.route_ec);
      u^.route_wait_val := ec_$read(u^.route_ec) + 1;
    end;
  end;
  ml_$exclusion_stop(u^.route_lock);
end;
