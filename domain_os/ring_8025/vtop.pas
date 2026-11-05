{ ring_8025_vtop - the address the adapter reaches a virtual address at.

  Image addresses:
    sau7  0x3C495BA8  ring_8025_vtop
    sau8  0x03C89338  ring_8025_vtop
    sau9  0x3C484F38  ring_8025_vtop

  - The page's frame from MMU_$VTOP, which must succeed (the system
    crashes otherwise), and the address's offset in its 1024-byte page:
    the physical address.
  - With `ring_8025_iomap' the len bytes from va are mapped at the I/O
    map's pages from bus_page, a page each, and the result is the bus
    address of va.  A page not mapped, or a mapping that fails, crashes
    the system.

  Status stored: none.
}

%if ring_8025_iomap %then
function ring_8025_vtop(va: integer32; len: integer; bus_page: integer):
  integer32; internal;
var
  off: integer;
  ppn: integer32;
  status: status_$t;
  page: integer;
begin
  off := va & 16#3FF;
  for page := bus_page
      to bus_page + (rshft(va + len - 1, 10) - rshft(va, 10)) do begin
    ppn := mmu_$vtop(va, status);
    if status.all = status_$ok then
      iomap_$map(r8025_iomap_bus, lshft(integer32(page), 10), ppn, 0, 1, 0,
                 status);
    if status.all <> status_$ok then
      crash_system(status);
    va := va + 1024;
  end;
  ring_8025_vtop := lshft(integer32(bus_page), 10) ! off;
end;
%else
function ring_8025_vtop(va: integer32): integer32; internal;
var
  ppn: integer32;
  status: status_$t;
begin
  ppn := mmu_$vtop(va, status);
  ring_8025_check_status(status);
  ring_8025_vtop := lshft(ppn, 10) + (va & 16#3FF);
end;
%endif
