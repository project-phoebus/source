{ ethernet_range_overlaps - whether a range of packet types overlaps one
  of a list's.

  Image addresses:
    sau8  0x03C85D2C  ethernet_range_overlaps
    sau9  0x3C48192C  ethernet_range_overlaps

  - first..last against the first count ranges of the list.

  Status stored: none.
}

function ethernet_range_overlaps(first: pinteger; last: pinteger;
                                 var list: ethernet_$range_list_t;
                                 count: integer): boolean;
  internal;
var
  i: integer;
begin
  for i := 1 to count do
    with list[i] do
      if (first <= high) and then (last >= low) then begin
        ethernet_range_overlaps := true;
        return;
      end;
  ethernet_range_overlaps := false;
end;
