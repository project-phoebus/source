{ ring_8025_find_range - the first of a list's ranges of frame types
  that overlaps a range.

  Image addresses:
    sau9  0x3C485F1E  ring_8025_find_range

  - first..last against the first count ranges of the list; the result
    is the range's index, 0 if none overlaps.

  Status stored: none.
}

function ring_8025_find_range(first: linteger; last: linteger;
                              var list: ring_8025_$range_list_t;
                              count: integer): integer;
  internal;
var
  i: integer;
begin
  for i := 1 to count do
    with list[i] do
      if (first <= high) and then (last >= low) then begin
        ring_8025_find_range := i;
        return;
      end;
  ring_8025_find_range := 0;
end;
