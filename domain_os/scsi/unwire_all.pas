{ scsi_unwire_all - unwire every page a device has wired.

  Image addresses:
    sau9  0x3C4A68A2  scsi_unwire_all

  - Walks the whole of physical memory's owner table.
}

procedure scsi_unwire_all(dev: integer);
var
  ppn: linteger;
  owners: scsi_owners_t;
  st: status_$t;
begin
  if scsi_$present then
    for ppn := mmap_$lppn to mmap_$hppn do begin
      owners := scsi_$ppn_owners[ppn];
      if (owners <> []) and then (dev in owners) then
        scsi_unwire_page(dev, ppn, st);
    end;
end;
