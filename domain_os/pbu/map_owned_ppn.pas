{ pbu_map_owned_ppn - the physical page of a virtual address, if the
  unit has it wired.

  Image addresses:
    sau3  0x00E89BE0  pbu_map_owned_ppn (module-local)
    sau5  0x00E91FAC  pbu_map_owned_ppn (module-local)
    sau8  0x03CA569C  pbu_map_owned_ppn (module-local)

  - 0 for a page not mapped, or for a page of MMAP_$LPPN..MMAP_$HPPN
    the unit does not own; a page outside that range is returned without
    the ownership test.

  Status stored: none.
}

function pbu_map_owned_ppn(unit: integer; va: linteger): linteger;
  internal;
var
  ppn: linteger;
  vtop_status: status_$t;
  owners: pbu_$unit_set_t;
begin
  ppn := mmu_$vtop(va, vtop_status);
  if vtop_status.all <> status_$ok then
    ppn := 0;
  if (ppn <> 0) and then (ppn >= mmap_$lppn) and then (ppn <= mmap_$hppn)
  then begin
    owners := pbu_$ppn_owners[ppn];
    if not (unit in owners) then
      ppn := 0;
  end;
  pbu_map_owned_ppn := ppn;
end;
