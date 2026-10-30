{ ring_8025_find_adjacent - the next of a channel's ranges of frame
  types that a range continues.

  Image addresses:
    sau9  0x3C485EA0  ring_8025_find_adjacent

  - From index idx to count: the first range of the unit's that belongs
    to channel and that first..last directly precedes or follows (its
    bounds taken from list); idx is left its index, or 0 if there is
    none.

  Status stored: none.
}

procedure ring_8025_find_adjacent(u: ring_8025_$unit_ptr_t;
                                  var idx: integer; channel: pinteger;
                                  first: linteger; last: linteger;
                                  var list: ring_8025_$range_list_t;
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
