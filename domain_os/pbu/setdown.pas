{ PBU_$SETDOWN - set down the PBU units PBU_$SETUP set up.

  Image addresses:
    sau3  0x00E592E4  PBU_$SETDOWN
    sau5  0x00E594B4  PBU_$SETDOWN
    sau8  0x03C61B1C  PBU_$SETDOWN

  - Under the exclusion lock, every set-up unit of the unit's bus that
    the same DDF unit set up is taken down: its device, user pages, map
    space, controller memory and DCTE.  Without the VME bus
    (`vme_bus') every unit is the Multibus's.
  - Its I/O unit is released (IO_$RELEASE), on the Multibus not while
    the unit sharing its vector (3 with 7) is still owned.
  - When the count of set-up units reaches 0, PBU_$WIRE_PBU's pages are
    unwired.  ddf is not read.
  - The CSR pages' loop steps the DCTE's own csr_ppn and csr_va, which
    are left past the pages (the DCTE is given back after it).

  Status stored:
    io_$release's status: the units were set down
    pbu_check_unit's status: the unit is not the caller's
    status_$pbu_global_device: the current process does not own the
      unit
    status_$pbu_not_present: the Multibus unit's bus is not present
}

procedure pbu_$setdown(in unit: integer; in ddf: pbu_$ddf_ptr_t;
                       out status: status_$t);
var
  dcte: pbu_$dcte_ptr_t;
  first: integer;
  last: integer;
  sub: integer;
  i: integer;
  sub_unit: integer;
  sub_status: status_$t;
  sub_dcte: pbu_$dcte_ptr_t;
  other: pbu_$dcte_ptr_t;
begin
  dcte := pbu_check_unit(unit, status);
  if status.all <> status_$ok then
    return;
  if dcte^.owner <> proc1_$current then begin
    status.all := status_$pbu_global_device;
    return;
  end;
%if vme_bus %then
  if dcte^.unit_info.bus = io_$bus_vme then begin
    first := pbu_first_vme_unit;
    last := pbu_$max_unit;
  end
  else
%endif
%if mbus_bus %then
  if not pbu_$mcb.present then begin
    status.all := status_$pbu_not_present;
    return;
  end
  else begin
    first := 0;
    last := pbu_first_vme_unit - 1;
  end;
%else
  begin
    first := 0;
    last := pbu_$max_unit;
  end;
%endif
  if not dcte^.flags.kernel_driver and then (dcte^.csr_ppn <> 0) then
    for i := 1 to dcte^.csr_pages do begin
%if large_vm %then
      mst_$remove_ioppn(dcte^.csr_va);
%else
      mmu_$remove(dcte^.csr_ppn);
%endif
      dcte^.csr_ppn := dcte^.csr_ppn + 1;
      dcte^.csr_va := dcte^.csr_va + 1024;
    end;
  ml_$exclusion_start(pbu_$exclusion_lock);
  for sub := first to last do begin
    if pbu_$dctes[sub] = nil then
      next;
    sub_dcte := pbu_$dctes[sub];
    if sub_dcte^.unit <> unit then
      next;
    if sub_dcte^.unit_info.bus = io_$bus_vme then begin
      sub_unit := sub;
      pbu_$enable_device(sub_unit, sub_status);
    end
    else begin
      sub_unit := sub;
      pbu_$disable_device(sub_unit, sub_status);
    end;
    sub_unit := sub;
    pbu_$unwire_user_pages(sub_unit);
    sub_unit := sub;
    pbu_$free_map(sub_unit, sub_status);
    sub_unit := sub;
    pbu_$dissoc(sub_unit, sub_status);
    sub_dcte^.owner := 0;
    pbu_$dctes[sub] := nil;
    sub_dcte^.unit := pbu_free_unit;
%if mbus_bus %then
    if sub_dcte^.unit_info.bus <> io_$bus_vme then begin
      case sub of
        3: other := pbu_$dctes[7];
        7: other := pbu_$dctes[3];
        otherwise
          other := nil;
      end;
      if other <> nil then
        if other^.owner <> 0 then
          next;
    end;
%endif
    io_$release(sub_dcte^.unit_info.io_unit, status);
  end;
  pbu_$mcb.setups := pbu_$mcb.setups - 1;
  if pbu_$mcb.setups < 0 then
    pbu_$mcb.setups := 0;
  if pbu_$mcb.setups = 0 then
    if pbu_$mcb.wired then begin
      for i := 1 to pbu_wired_count do
        wp_$unwire(pbu_wired_pages[i]);
      pbu_$mcb.wired := false;
    end;
  ml_$exclusion_stop(pbu_$exclusion_lock);
end;
