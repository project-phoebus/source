{ io_$remove_region - take a region out of a unit's region list.

  Image addresses:
    sau3  0x00E19E3C  io_$remove_region
    sau5  0x00E1B0F4  io_$remove_region

  - The node is unlinked from the slot's list and goes to the head of
    the free list (io_$region_free), also when it was not in the list.

  Status stored: none.
}

procedure io_$remove_region(var slot: io_$unit_entry_t;
                            p: io_$region_ptr_t);
  internal;
var
  q: io_$region_ptr_t;
begin
  if slot.regions = p then
    slot.regions := p^.next
  else begin
    q := slot.regions;
    while q <> nil do begin
      if q^.next = p then begin
        q^.next := p^.next;
        exit;
      end;
      q := q^.next;
    end;
  end;
  p^.next := io_$region_free;
  io_$region_free := p;
end;
