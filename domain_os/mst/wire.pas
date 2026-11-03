{ MST_$WIRE - wire the page of a virtual address, touching it in if it
  is not resident.

  Image addresses:
    sau2  0x00E0E1BC  MST_$WIRE
    sau8  0x03C0F5A4  MST_$WIRE
    sau9  0x3C410690  MST_$WIRE

  - Under the PMAP lock a mapped address has its page wired and its
    number returned; otherwise MST_$TOUCH brings it in wired and its
    result is returned.

  Status stored:
    MMU_$VTOP's or MST_$TOUCH's status: in either case
}

function mst_$wire(vpn: integer32; out status: status_$t): integer32;
var
  ppn: integer32;
  local_status: status_$t;
begin
%if pmap_threads %then
  { the page is always faulted in, wired }
  mst_$wire := mst_$touch(vpn, local_status, 1);
%else
  ml_$lock(ml_$pmap_lock);
  ppn := mmu_$vtop(vpn, local_status);
  if local_status.all = status_$ok then begin
    mmap_$wire(ppn);
    ml_$unlock(ml_$pmap_lock);
    mst_$wire := ppn;
  end
  else begin
    ml_$unlock(ml_$pmap_lock);
    mst_$wire := mst_$touch(vpn, local_status, 1);
  end;
%endif
  status := local_status;
end;
