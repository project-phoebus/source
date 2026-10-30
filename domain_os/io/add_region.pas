{ io_$add_region - record an I/O map region in a unit's region list.

  Image addresses:
    sau5  0x00E1B0A2  io_$add_region

  - A node off the free list (io_$region_free) gets the region's page,
    start and stop and goes at the head of the slot's list; an empty
    free list crashes the system.  With the PBU only (`io_regions').

  Status stored: none.
}

procedure io_$add_region(var slot: io_$unit_entry_t; page: integer;
                         start: linteger; stop: linteger);
  internal;
var
  p: io_$region_ptr_t;
begin
  if io_$region_free = nil then
    crash_system(status_$io_region_crash);
  p := io_$region_free;
  io_$region_free := p^.next;
  p^.next := slot.regions;
  p^.page := page;
  p^.start := start;
  p^.stop := stop;
  slot.regions := p;
end;
