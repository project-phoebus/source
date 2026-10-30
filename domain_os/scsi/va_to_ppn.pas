{ scsi_va_to_ppn - the physical page of a buffer's page, if the device
  has it wired.

  Image addresses:
    sau9  0x3C4A4E3C  scsi_va_to_ppn

  - A user address is looked up in the current address space (MST),
    a system address in the MMU.
  - Returns the page number, or 0 when the address has no page or a
    user page of physical memory is not wired for the device (dev, its
    bus * 8 + target).
}

function scsi_va_to_ppn(dev: integer; va: integer32): integer32; internal;
var
  status: status_$t;
  ppn: integer32;
  owners: scsi_owners_t;
begin
  status.all := status_$ok;
  if linteger(va) < 16#3C000000 then
    ppn := mst_$find(va, 0)
  else begin
    ppn := mmu_$vtop(va, status);
    if status.all <> status_$ok then
      ppn := 0;
  end;
  if (ppn <> 0) and then (linteger(va) < 16#3C000000)
     and then (linteger(ppn) >= mmap_$lppn)
     and then (linteger(ppn) <= mmap_$hppn) then begin
    owners := scsi_$ppn_owners[ppn];
    if not (dev in owners) then
      ppn := 0;
  end;
  scsi_va_to_ppn := ppn;
end;
