{ ring_8025_find_type - the first of a list's ranges of frame types
  that holds a type.

  Image addresses:
    sau7  0x3C496BBA  ring_8025_find_type
    sau8  0x03C8A20E  ring_8025_find_type
    sau9  0x3C485E12  ring_8025_find_type

  - t against the first count ranges of the list; the result is the
    range's index, 0 if none holds it.

  Status stored: none.
}

function ring_8025_find_type(t: linteger;
                              var list: ring_8025_$range_list_t;
                              count: integer): integer;
  internal;
var
  i: integer;
begin
  for i := 1 to count do
    with list[i] do
      if (t >= low) and then (t <= high) then begin
        ring_8025_find_type := i;
        return;
      end;
  ring_8025_find_type := 0;
end;
