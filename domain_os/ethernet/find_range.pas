{ ethernet_find_range - the first of a list's ranges of packet types
  that overlaps a range.

  Image addresses:
    sau9  0x3C4819F2  ethernet_find_range

  - first..last against the first count ranges of the list; the result
    is the range's index, 0 if none overlaps.

  Status stored: none.
}

function ethernet_find_range(first: pinteger; last: pinteger;
                             var list: ethernet_$range_list_t;
                             count: integer): integer;
  internal;
var
  i: integer;
begin
  for i := 1 to count do
    with list[i] do
      if (first <= high) and then (last >= low) then begin
        ethernet_find_range := i;
        return;
      end;
  ethernet_find_range := 0;
end;
