{ io_$free_region - free a range of bus addresses in a bus's I/O map.

  Image addresses:
    sau3  0x00E19C92  io_$free_region
    sau4  0x0F81B84A  io_$free_region
    sau5  0x00E1AF42  io_$free_region
    sau6  0x7801C4E8  io_$free_region
    sau7  0x3C41E74C  io_$free_region
    sau8  0x03C1BD68  io_$free_region

  - Under io_$exclusion the range starting at iova is removed and the
    later ones moved down; a start no range has crashes the system
    (status_$pbu_invalid_iova).
  - The search reports 0 for none.

  Status stored: none.
}

procedure io_$free_region(bus: integer; iova: linteger);
  internal;
var
  map: io_$iomap_ptr_t;
  found: integer;
  i: integer;
begin
  ml_$exclusion_start(io_$exclusion);
  map := io_$iomap_area.maps[bus];
  found := 0;
  for i := map^.last downto map^.first do
    with map^.ranges[i] do
      if start = iova then begin
        found := i;
        exit;
      end;
  if found = 0 then
    crash_system(status_$pbu_invalid_iova)
  else begin
    map^.last := map^.last - 1;
    for i := found to map^.last do
      map^.ranges[i] := map^.ranges[i + 1];
  end;
  ml_$exclusion_stop(io_$exclusion);
end;
