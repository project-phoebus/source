{ ring_8025_learn_local - learn that a station is on this ring.

  Image addresses:
    sau9  0x3C4862C4  ring_8025_learn_local

  - Hands ring_8025_learn_route a header from the station with a
    routing field of only its control word.

  Status stored: none.
}

procedure ring_8025_learn_local(u: ring_8025_$unit_ptr_t;
                                in station: ring_8025_$addr_t);
  internal;
var
  hdr: ring_8025_$mac_hdr_t;
begin
  hdr.src.high := station.high;
  hdr.src.low := station.low;
  hdr.rif.rc.len := 2;
  ring_8025_learn_route(u, hdr);
end;
