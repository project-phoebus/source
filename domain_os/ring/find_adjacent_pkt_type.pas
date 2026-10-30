{ ring_$find_adjacent_pkt_type - the next entry of a channel's packet types
  that a range adjoins.

  Image addresses:
    sau2  0x00E7639E  ring_$find_adjacent_pkt_type (module-local)

  - From entry idx on, the first of the channel's entries whose range
    ends just below the given range or starts just above it gives its
    index in idx; with none, idx is 0.

  Status stored: none.
}

procedure ring_$find_adjacent_pkt_type(var unit: ring_$unit_t;
                                       var idx: integer;
                                       channel: integer;
                                       lo: linteger; hi: linteger;
                                       in table: ring_$pkt_table_t;
                                       count: integer);
  internal;
var
  i: integer;
begin
  for i := idx to count do
    with table[i].entry.range do
      if channel = unit.pkt_types[i].entry.channel then
        if (low - 1 = hi) or else (high + 1 = lo) then begin
          idx := i;
          return;
        end;

  idx := 0;
end;
