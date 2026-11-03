{ MST_$FIND - the physical page of a virtual address, touching it in if
  it is not resident.

  Image addresses:
    sau2  0x00E0E11E  MST_$FIND
    sau8  0x03C0F55C  MST_$FIND
    sau9  0x3C410648  MST_$FIND

  - Flags bits 0 and 2 crash the system (a caller's error); bit 1 asks
    for the page to be wired.
  - Under the PMAP lock a mapped address gives its page (wired as asked);
    otherwise MST_$TOUCH brings it in and its result is returned.

  Status stored: none.
}

function mst_$find(virt_addr: integer32; flags: integer): integer32;
var
  ppn: integer32;
  status: status_$t;
begin
  if (flags & 5) <> 0 then
    crash_system(status_$reference_to_out_of_bounds_address);
%if pmap_threads %then
  { the page is always faulted in }
  if (flags & 2) <> 0 then
    mst_$find := mst_$touch(virt_addr, status, 1)
  else
    mst_$find := mst_$touch(virt_addr, status, 0);
%else
  ml_$lock(ml_$pmap_lock);
  ppn := mmu_$vtop(virt_addr, status);
  if status.all = status_$ok then begin
    if (flags & 2) <> 0 then
      mmap_$wire(ppn);
    ml_$unlock(ml_$pmap_lock);
    mst_$find := ppn;
  end
  else begin
    ml_$unlock(ml_$pmap_lock);
    if (flags & 2) <> 0 then
      mst_$find := mst_$touch(virt_addr, status, 1)
    else
      mst_$find := mst_$touch(virt_addr, status, 0);
  end;
%endif
end;
