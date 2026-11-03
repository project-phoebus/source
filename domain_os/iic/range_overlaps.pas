{ iic_range_overlaps - whether a range meets any range of a line's
  packet-type table.

  Image addresses:
    sau3  0x00E72176  iic_range_overlaps (module-local)

  - True when one of the count entries has lo <= its high and hi >= its
    low; the compares are unsigned.

  Status stored: none.
}

function iic_range_overlaps(lo: linteger; hi: linteger;
                            in table: iic_$pkt_table_t;
                            count: integer): boolean;
  internal;
var
  i: integer;
begin
  for i := 1 to count do
    with table[i].entry.range do
      if (lo <= high) and then (hi >= low) then begin
        iic_range_overlaps := true;
        return;
      end;

  iic_range_overlaps := false;
end;
