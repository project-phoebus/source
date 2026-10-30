{ ring_$find_overlapping_pkt_type - the first entry of a packet-type table
  that a range meets.

  Image addresses:
    sau2  0x00E76422  ring_$find_overlapping_pkt_type (module-local)

  - As ring_$pkt_type_overlaps, giving the entry's index (from 1) or 0.

  Status stored: none.
}

function ring_$find_overlapping_pkt_type(lo: linteger; hi: linteger;
                                         in table: ring_$pkt_table_t;
                                         count: integer): integer;
  internal;
var
  i: integer;
begin
  for i := 1 to count do
    with table[i].entry.range do
      if (lo <= high) and then (hi >= low) then begin
        ring_$find_overlapping_pkt_type := i;
        return;
      end;

  ring_$find_overlapping_pkt_type := 0;
end;
