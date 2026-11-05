{ PBU_$DISSOC - unmap a PBU unit's controller memory.

  Image addresses:
    sau3  0x00E58DD0  PBU_$DISSOC
    sau4  0x0F861A18  PBU_$DISSOC
    sau5  0x00E58F94  PBU_$DISSOC
    sau6  0x78060CB6  PBU_$DISSOC
    sau7  0x3C469724  PBU_$DISSOC
    sau8  0x03C6173E  PBU_$DISSOC

  - Undoes PBU2_$ASSOC: the memory's I/O map space is freed (a failure
    crashes the system) and its pages' MMU entries removed.
  - The page wraps from 16#400 to 16#E00 on a bus other than the VME
    bus, where PBU2_$ASSOC tests for the Multibus: the same on the
    SAU5, whose units are on those two buses.  Without the VME bus
    (`vme_bus') the wrap does not test the bus.

  Status stored:
    status_$ok: the memory was unmapped
    pbu_check_unit's status: the unit is not the caller's
    status_$pbu_buffer_not_mapped: the unit has no controller memory
      mapped
}

procedure pbu_$dissoc(in unit: integer; out status: status_$t);
var
  dcte: pbu_$dcte_ptr_t;
  npages: integer32;
%if large_vm %then
  va: linteger;
%else
  ppn: linteger;
%endif
  i: integer32;
begin
  dcte := pbu_check_unit(unit, status);
  if status.all <> status_$ok then
    return;
  if dcte^.assoc_length = 0 then begin
    status.all := status_$pbu_buffer_not_mapped;
    return;
  end;
  npages := (dcte^.assoc_length + 1023) div 1024;
%if not large_vm %then
  ppn := dcte^.assoc_iova div 1024;
  if dcte^.unit_info.bus <> io_$bus_vme then
    if dcte^.assoc_iova < 16#80000 then
      ppn := ppn + 16#200
    else
      ppn := ppn + 16#C00;
%endif
  io_$free(dcte^.unit_info.io_unit, dcte^.assoc_iova, status);
  if status.all <> status_$ok then
    crash_system(status);
%if large_vm %then
  va := dcte^.assoc_va;
  for i := 1 to npages do begin
    mst_$remove_ioppn(va);
    va := va + 1024;
  end;
%else
  for i := 1 to npages do begin
    mmu_$remove(ppn);
    ppn := ppn + 1;
%if vme_bus %then
    if (ppn = 16#400) and then (dcte^.unit_info.bus <> io_$bus_vme) then
%else
    if ppn = 16#400 then
%endif
      ppn := 16#E00;
  end;
%endif
  dcte^.assoc_length := 0;
end;
