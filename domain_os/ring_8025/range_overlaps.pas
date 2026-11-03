{ ring_8025_range_overlaps - whether a range of frame types overlaps one
  of a list's.

  Image addresses:
    sau8  0x03C8A256  ring_8025_range_overlaps
    sau9  0x3C485E5A  ring_8025_range_overlaps

  - first..last against the first count ranges of the list.

  Status stored: none.
}

function ring_8025_range_overlaps(first: linteger; last: linteger;
                                  var list: ring_8025_$range_list_t;
                                  count: integer): boolean;
  internal;
var
  i: integer;
begin
  for i := 1 to count do
    with list[i] do
      if (first <= high) and then (last >= low) then begin
        ring_8025_range_overlaps := true;
        return;
      end;
  ring_8025_range_overlaps := false;
end;
