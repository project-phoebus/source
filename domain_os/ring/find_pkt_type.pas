{ ring_$find_pkt_type - the entry of a packet-type table whose range holds
  a type.

  Image addresses:
    sau2  0x00E7630C  ring_$find_pkt_type (module-local)

  - The index (from 1) of the first entry with low <= key <= high, or 0;
    the compares are unsigned.

  Status stored: none.
}

function ring_$find_pkt_type(key: linteger; in table: ring_$pkt_table_t;
                             count: integer): integer;
  internal;
var
  i: integer;
begin
  for i := 1 to count do
    with table[i].entry.range do
      if (key >= low) and then (key <= high) then begin
        ring_$find_pkt_type := i;
        return;
      end;

  ring_$find_pkt_type := 0;
end;
