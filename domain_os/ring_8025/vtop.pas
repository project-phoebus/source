{ ring_8025_vtop - the physical address of a virtual address.

  Image addresses:
    sau9  0x3C484F38  ring_8025_vtop

  - The page's frame from MMU_$VTOP, which must succeed (the system
    crashes otherwise), and the address's offset in its 1024-byte page.
}

function ring_8025_vtop(va: integer32): integer32; internal;
var
  ppn: integer32;
  status: status_$t;
begin
  ppn := mmu_$vtop(va, status);
  ring_8025_check_status(status);
  ring_8025_vtop := lshft(ppn, 10) + (va & 16#3FF);
end;
