{ ring_8025_map_pa - map a physical address's page at a bus page.

  Image addresses:
    sau7  0x3C495B40  ring_8025_map_pa

  - The page of pa is mapped at bus_page of the I/O map; the result is
    the bus address of pa: the bus page's address and pa's offset in its
    1024-byte page.
  - A failed mapping crashes the system.

  Status stored: none.
}

function ring_8025_map_pa(pa: integer32; bus_page: integer): integer32;
  internal;
var
  status: status_$t;
  ppn: integer32;
  off: pinteger;
  iova: integer32;
begin
  off := pa & 16#3FF;
  ppn := rshft(pa, 10);
  iova := lshft(integer32(bus_page), 10);
  iomap_$map(r8025_iomap_bus, iova, ppn, 0, 1, 0, status);
  ring_8025_check_status(status);
  ring_8025_map_pa := iova ! off;
end;
