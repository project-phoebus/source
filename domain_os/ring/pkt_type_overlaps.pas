{ ring_$pkt_type_overlaps - whether a range meets any range of a
  packet-type table.

  Image addresses:
    sau2  0x00E76352  ring_$pkt_type_overlaps (module-local)
    sau8  0x03C82C32  ring_$pkt_type_overlaps (module-local)

  - True when one of the count entries has lo <= its high and hi >= its
    low; the compares are unsigned.

  Status stored: none.
}

function ring_$pkt_type_overlaps(lo: linteger; hi: linteger;
                                 in table: ring_$pkt_table_t;
                                 count: integer): boolean;
  internal;
var
  i: integer;
begin
  for i := 1 to count do
    with table[i].entry.range do
      if (lo <= high) and then (hi >= low) then begin
        ring_$pkt_type_overlaps := true;
        return;
      end;

  ring_$pkt_type_overlaps := false;
end;
