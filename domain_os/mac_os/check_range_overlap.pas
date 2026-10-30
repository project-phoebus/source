{ mac_os_$check_range_overlap - whether a packet-type range overlaps one
  in a port's table.

  Image addresses:
    sau2  0x00E0B1BC  mac_os_$check_range_overlap (module-local)

  - True at the first of the first count entries whose range the new
    one overlaps (the bounds compared unsigned); else false.

  Status stored: none.
}

{ TODO(pascal) two frame bytes of mac_os_$check_range_overlap hold nothing

  The reserved slot (4), i (2), the result (2) and the `with' temporary
  (4) make 12; the stand-in unused_e holds the other two (with them 14,
  rounded to 16).  mac_os_$find_packet_type, the same loop with the
  index formed, has the same frame; a 2-byte cost of a `for' loop would
  explain both ("a 2-byte one would still round away" at the sites
  surveyed).  Not settled. }

function mac_os_$check_range_overlap(in new_range: mac_os_$pkt_type_range_t;
                                     in table: mac_os_$pkt_type_array_t;
                                     count: integer): boolean; internal;
var
  i: integer;                             { never formed }
  unused_e: integer;                      { stand-in: TODO above }
begin
  for i := 0 to count - 1 do
    with table[i] do
      if (new_range.range_low <= range.range_high)
         and then (new_range.range_high >= range.range_low) then begin
        mac_os_$check_range_overlap := true;
        return;
      end;

  mac_os_$check_range_overlap := false;
end;
