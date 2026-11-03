{ netbuf_rtnva_locked - give back a buffer page's slot of the window.

  Image addresses:
    sau2  0x00E0E8C4  netbuf_rtnva_locked (module-local)
    sau8  0x03C0FC3C  netbuf_rtnva_locked (module-local)
    sau9  0x3C410D28  netbuf_rtnva_locked (module-local)

  Assume we're called with the netbuf spin lock held.

  - The slot is the page's offset in the window divided by 1024; one
    outside 0..191 crashes the system.  The page is unmapped, the slot
    put at the free list's head and its physical address returned.
  - With the large VM layout MMU_$REMOVE takes the virtual address.

  Status stored: none.
}

function netbuf_rtnva_locked(in va: univ integer32): integer32; internal;
var
  slot: integer32;
  phys: integer32;
begin
  slot := (va - netbuf_$va_base_addr) div 1024;

  if (slot < 0) or else (slot > 191) then
    crash_system(status_$network_buffer_error);

  phys := netbuf_$va_slots[slot];
%if large_vm %then
  mmu_$remove(univ_ptr(va), 0);
%else
  mmu_$remove(rshft(phys, 10));
%endif
  netbuf_$va_slots[slot] := netbuf_$va_top;
  netbuf_$va_top := slot;
  netbuf_rtnva_locked := phys;
end;
