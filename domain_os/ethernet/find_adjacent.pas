{ ethernet_find_adjacent - the next of a channel's ranges of packet types
  that a range continues.

  Image addresses:
    sau9  0x3C48196E  ethernet_find_adjacent

  - From index idx to count: the first range of the unit's that belongs
    to chan and that first..last directly precedes or follows (its bounds
    taken from list); idx is left its index, or 0 if there is none.

  Status stored: none.
}

procedure ethernet_find_adjacent(u: ethernet_$unit_ptr_t; var idx: integer;
                                 channel: integer; first: pinteger;
                                 last: pinteger;
                                 var list: ethernet_$range_list_t;
                                 count: integer);
  internal;
var
  i: integer;
begin
  for i := idx to count do
    with list[i] do
      if u^.ranges[i].chan = channel then
        if (last = low - 1) or else (first = high + 1) then begin
          idx := i;
          return;
        end;
  idx := 0;
end;
