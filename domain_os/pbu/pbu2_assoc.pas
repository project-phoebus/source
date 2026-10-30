{ PBU2_$ASSOC - map a PBU unit's controller memory.

  Image addresses:
    sau5  0x00E58B8E  window_free (nested)
    sau5  0x00E58C08  PBU2_$ASSOC

  - The memory's I/O map space is allocated at iova and its pages
    installed at va, with protection 6 and the owner's address space
    unless the unit is global or va is in the global range.
  - Unless it may use any address, a VME unit's iova must be in the
    Multibus window (16#80000..16#FFFFF, free), which turns the Multibus
    off, or the upper window (16#380000..16#3FFFFF, its upper half free).
  - window_free (nested) allocates and frees the space to see that it is
    free; with the Multibus off it counts as free.

  Status stored:
    io_$alloc's status: the memory was mapped, or its space not
      allocated
    pbu_check_unit's status: the unit is not the caller's
    status_$pbu_controller_already_mapped: the unit has memory mapped
    status_$pbu_bad_controller_memory_length: length is not positive, or
      too long for the window
    status_$pbu_invalid_iova: iova is outside the windows, or taken
}

procedure pbu2_$assoc(in unit: integer; in va: linteger; in iova: linteger;
                      in length: integer32; out status: status_$t);
var
  range: as_$addr_range_t;
  dcte: pbu_$dcte_ptr_t;
  asid: integer;
  npages: integer32;
  addr_va: linteger;
  ppn: linteger;
  a: linteger;
  i: integer32;

  function window_free(offset: linteger): boolean; options(val_param);
  var
    free_status: status_$t;
  begin
    if pbu_$mcb.present then begin
      discard(io_$alloc(dcte^.unit_info.io_unit, 16#80000, true, offset,
                        status));
      if status.all = status_$ok then
        io_$free(dcte^.unit_info.io_unit, offset, free_status);
    end
    else
      status.all := status_$ok;
    window_free := status.all = status_$ok;
  end;

begin
  dcte := pbu_check_unit(unit, status);
  if status.all <> status_$ok then
    return;
  if dcte^.assoc_length <> 0 then begin
    status.all := status_$pbu_controller_already_mapped;
    return;
  end;
  if length <= 0 then begin
    status.all := status_$pbu_bad_controller_memory_length;
    return;
  end;
  npages := (length + 1023) div 1024;
  if dcte^.unit_info.bus = io_$bus_vme then begin
    a := iova;
    if (a >= 16#80000) and then (a < 16#100000) then begin
      if length > 16#80000 then begin
        status.all := status_$pbu_bad_controller_memory_length;
        return;
      end;
      if a + length > 16#100000 then begin
        status.all := status_$pbu_invalid_iova;
        return;
      end;
      if not window_free(0) then
        return;
      if not window_free(16#80000) then
        return;
      if pbu_$mcb.present then begin
        pbu_$mcb.present := false;
        pbu_ctl.word_00 := 16#213;
      end;
    end
    else if (a >= 16#380000) and then (a < 16#400000) then begin
      if length > 16#80000 then begin
        status.all := status_$pbu_bad_controller_memory_length;
        return;
      end;
      if (a + length > 16#400000) or else not pbu_$mcb.high_ok then begin
        status.all := status_$pbu_invalid_iova;
        return;
      end;
      if not window_free(16#80000) then
        return;
      if pbu_$mcb.present then begin
        pbu_$mcb.high_window := true;
        pbu_ctl.word_00 := 16#213;
      end;
    end
    else if not dcte^.flags.any_address then begin
      status.all := status_$pbu_invalid_iova;
      return;
    end;
    dcte^.assoc_iova := io_$alloc(dcte^.unit_info.io_unit, npages * 1024,
                                  true, iova, status);
  end;
  if dcte^.unit_info.bus = io_$bus_mbus then
    dcte^.assoc_iova := io_$alloc(dcte^.unit_info.io_unit, npages * 1024,
                                  true, iova, status);
  if status.all <> status_$ok then
    return;
  addr_va := va;
  dcte^.assoc_va := addr_va;
  if dcte^.flags.global then
    asid := 0
  else begin
    as_$get_addr(range, 1);
    if (dcte^.assoc_va >= range.base) and then
       (range.base + range.size > dcte^.assoc_va) then
      asid := 0
    else
      asid := proc1_$as_id;
  end;
  dcte^.assoc_length := length;
  ppn := iova div 1024;
  if dcte^.unit_info.bus <> io_$bus_vme then
    if iova < 16#80000 then
      ppn := ppn + 16#200
    else
      ppn := ppn + 16#C00;
  for i := 1 to npages do begin
    mmu_$install(ppn, univ_ptr(addr_va), asid, 6);
    ppn := ppn + 1;
    if (ppn = 16#400) and then (dcte^.unit_info.bus = io_$bus_mbus) then
      ppn := 16#E00;
    addr_va := addr_va + 1024;
  end;
end;
