{ PBU_$SETUP - set up the PBU units a DDF describes.

  Image addresses:
    sau3  0x00E594E0  PBU_$SETUP
    sau4  0x0F8620E8  PBU_$SETUP
    sau5  0x00E596D0  PBU_$SETUP
    sau8  0x03C61CB8  PBU_$SETUP

  - Under the exclusion lock.  The DDF's unit must be free; its bus is
    the VME bus for units 8..15 (`vme_bus'), the Multibus (present)
    otherwise.
  - The CSR pages (none when csr_pa is 16#FFFFFFFF) start on a page, on
    the VME bus in 16#C000..16#D000 unless the DDF allows any address.
  - Without the VME bus, bus is always the Multibus; with the AT bus's
    units (`pbu_atbus_units') the AT bus, whose CSR pages are groups of
    8 I/O ports in 16#100..16#3FF.
  - With the large virtual memory (`large_vm') the CSR pages are mapped
    by MST_$INSTALL_IOPPN, for a unit with no kernel driver only.
  - The PBU page is wired here unless OS_$INIT wires it
    (`pbu_wire_at_boot').
  - Every unit of the bus that is the DDF's or has a handler in it gets
    a free DCTE and its interrupt (IO_$ACQUIRE); its CSR pages are
    installed in the MMU.  A failure sets down what was set up.
  - The request's attributes are cleared only for the DDF's own unit.
    The DDF's wide I/O map flag gives every unit the wide map, but with
    the 64 KB Multibus map (`mbus_map_64k'), which has none.
  - A Multibus unit's CSR pages are the bus's from page 16#1C0, or with
    its window at 16#10000 (`mbus_low_window') from page 16#60.

  Status stored:
    status_$ok: the units were set up
    status_$pbu_wrong_pbulib_version: lib_version or the DDF's version
      is wrong
    status_$pbu_unit_already_acquired: the DDF's unit is set up
    status_$pbu_global_device: the DDF's unit is a global device
    status_$pbu_not_present: a Multibus unit without the Multibus
      present
    status_$pbu_invalid_csr_page_address: the CSR pages are misplaced
    status_$pbu_unit_in_use: a unit of the bus is set up already
    status_$pbu_all_units_in_use: no free DCTE
    io_$acquire's status, its fail bit set: an interrupt could not be
      acquired
}

procedure pbu_$setup(in lib_version: integer; in ddf: pbu_$ddf_ptr_t;
                     out status: status_$t);
label
  done, unlock;
var
  d: pbu_$ddf_ptr_t;
  unit: pinteger;
  dcte: pbu_$dcte_ptr_t;
  bus: 0..7;
  first: integer;
  last: integer;
  csr_ppn: integer32;
  csr_end: linteger;
  sub: integer;
  i: integer;
  vector: integer;
  handler: univ_ptr;
  handler_arg: univ_ptr;
  req: io_$acquire_rec_t;
  io_unit: io_$unit_num_t;
  prot: integer;
  asid: integer;
  va: linteger;
  setdown_unit: integer;
  setdown_status: status_$t;
begin
  d := ddf;
  if (lib_version <> pbu_lib_version) or else
     (d^.flags.version <> pbu_ddf_version) then begin
    status.all := status_$pbu_wrong_pbulib_version;
    return;
  end;
  unit := d^.unit;
  ml_$exclusion_start(pbu_$exclusion_lock);
  dcte := pbu_check_unit(unit, status);
  if status.all = status_$pbu_unit_not_acquired then
    status.all := status_$ok
  else begin
    if status.all = status_$ok then
      if dcte^.flags.global then
        status.all := status_$pbu_global_device
      else
        status.all := status_$pbu_unit_already_acquired;
    if status.all <> status_$ok then
      goto unlock;
  end;
%if vme_bus %then
  if unit >= pbu_first_vme_unit then begin
    bus := io_$bus_vme;
    first := pbu_first_vme_unit;
    last := pbu_$max_unit;
  end
  else
%endif
%if pbu_atbus_units %then
  begin
    bus := io_$bus_atbus;
    first := 0;
    last := pbu_$max_unit;
  end;
%else
  begin
    if not pbu_$mcb.present then begin
      status.all := status_$pbu_not_present;
      goto unlock;
    end;
    bus := io_$bus_mbus;
    first := 0;
    last := pbu_first_vme_unit - 1;
  end;
%endif
  if d^.csr_pa = -1 then
    csr_ppn := 0
  else begin
    if (d^.csr_pa & (pbu_csr_page_size - 1)) <> 0 then begin
      status.all := status_$pbu_invalid_csr_page_address;
      goto unlock;
    end;
    csr_end := d^.csr_pages * pbu_csr_page_size + d^.csr_pa;
    if bus = io_$bus_vme then begin
      if not d^.flags.any_address then
        if (linteger(d^.csr_pa) < 16#C000) or else (csr_end > 16#D000) then
        begin
          status.all := status_$pbu_invalid_csr_page_address;
          goto unlock;
        end;
      csr_ppn := linteger(d^.csr_pa) div 1024;
    end;
    if bus = io_$bus_mbus then begin
      if (d^.csr_pa < 0) or else (csr_end > 16#10000) then begin
        status.all := status_$pbu_invalid_csr_page_address;
        goto unlock;
      end;
%if mbus_low_window %then
      csr_ppn := d^.csr_pa div 1024 + 16#60;
%else
      csr_ppn := d^.csr_pa div 1024 + 16#1C0;
%endif
    end;
%if pbu_atbus_units %then
    if bus = io_$bus_atbus then begin
      if (d^.csr_pa < pbu_atbus_csr_first) or else
         (csr_end > pbu_atbus_csr_end) then begin
        status.all := status_$pbu_invalid_csr_page_address;
        goto unlock;
      end;
      csr_ppn := d^.csr_pa div pbu_csr_page_size + pbu_atbus_io_ppn;
    end;
%endif
  end;

  for sub := first to last do begin
    if (sub <> unit) and then (d^.handlers[sub] = univ_ptr(pbu_no_handler)) then
      next;
    if pbu_$dctes[sub] <> nil then begin
      status.all := status_$pbu_unit_in_use;
      goto done;
    end;
    dcte := nil;
    for i := 0 to pbu_dcte_table_last do
      if pbu_$dcte_table[i]^.owner = 0 then begin
        dcte := pbu_$dcte_table[i];
        exit;
      end;
    if dcte = nil then begin
      status.all := status_$pbu_all_units_in_use;
      goto done;
    end;
    for i := 1 to 84 do
      pbu_$dcte_bytes_ptr_t(dcte)^[i] := chr(0);
    vector := sub;
%if mbus_bus %then
    if sub = 7 then
      vector := 3;
%endif
    handler := addr(pbu_$int_com);
    if d^.flags.kernel_driver then begin
      dcte^.device_routine := d^.handlers[sub];
      handler_arg := d^.handler_arg;
      if handler_arg = nil then
        handler_arg := dcte
      else
        handler := dcte^.device_routine;
    end
    else begin
      handler_arg := dcte;
      dcte^.user_stack := d^.stack;
      dcte^.user_handler := d^.handlers[sub];
      if dcte^.user_handler <> nil then
        dcte^.device_routine := addr(pbu_$user_space_driver)
      else
        dcte^.device_routine := addr(pbu_$advance_only);
    end;
    dcte^.owner := proc1_$current;
    req.tag := 3;
    req.bus := bus;
    req.int.has_int := true;
    case bus of
      1, 2, 3, 4: req.int.id.vector := vector;
    end;
    if sub = unit then begin
      req.csr.has_csr := csr_ppn <> 0;
      req.csr.pages := d^.csr_pages;
      req.csr.va := d^.csr_va;
      req.csr.pa := d^.csr_pa;
      req.attrs := [];
    end
    else
      req.csr.has_csr := false;
%if not mbus_map_64k %then
    if d^.flags.wide_iomap then
      req.attrs := [io_$attr_wide_iomap];
%endif
    io_$acquire(req, handler, handler_arg, io_unit, status);
    if status.all <> status_$ok then begin
      status.fail := true;
      goto done;
    end;
    pbu_$dctes[sub] := dcte;
    dcte^.unit_info.io_unit := io_unit;
    dcte^.vector := vector;
    dcte^.asid := proc1_$as_id;
    dcte^.unit_info.cur_asid := dcte^.asid;
    dcte^.flags.active := true;
    dcte^.flags.kernel_driver := d^.flags.kernel_driver;
    dcte^.flags.any_address := d^.flags.any_address;
    dcte^.unit_info.bus := bus;
    dcte^.flags.global := d^.flags.global;
    dcte^.unit := unit;
    dcte^.csr_ppn := csr_ppn;
    dcte^.csr_pages := d^.csr_pages;
    dcte^.ec_ptr := addr(dcte^.ec);
%if pbu_atbus_units %then
    dcte^.flags.attr_set := false;
    dcte^.flags.cleared_7 := false;
%else
    dcte^.flags.cleared_8_7 := 0;
%endif
    dcte^.flags.cleared_0 := false;
    dcte^.csr_va := d^.csr_va;
    va := dcte^.csr_va;
    ec_$init(dcte^.ec);
%if pbu_transfer_control %then
    dcte^.ctl := pbu_default_ctl;
%else
    dcte^.ctl.all := 0;
%endif
    case dcte^.unit_info.bus of
      2, 3: dcte^.flags.dma_bus := true;
      1: dcte^.flags.dma_bus := false;
    end;
  end;

%if large_vm %then
  if not d^.flags.kernel_driver and then (csr_ppn <> 0) then
    for i := 1 to d^.csr_pages do begin
      mst_$install_ioppn(csr_ppn, va, setdown_status);
      csr_ppn := csr_ppn + 1;
      va := va + 1024;
    end;
%else
  if d^.flags.kernel_driver then begin
    prot := 16#16;
    asid := 0;
  end
  else begin
    prot := 6;
    if d^.flags.global then
      asid := 0
    else
      asid := proc1_$as_id;
  end;
  if csr_ppn <> 0 then
    for i := 1 to d^.csr_pages do begin
      mmu_$install(csr_ppn, univ_ptr(va), asid, prot);
      csr_ppn := csr_ppn + 1;
      va := va + 1024;
    end;
%endif
  pbu_$mcb.setups := pbu_$mcb.setups + 1;
  if bus = io_$bus_vme then begin
    if not pbu_$mcb.owners_mapped then
      pbu_$init(false);
    pbu_$mcb.vme_set_up := true;
  end;
%if not pbu_wire_at_boot %then
  if unit <> pbu_sm_unit then
    pbu_$wire_pbu;
%endif
  if not d^.flags.kernel_driver then
    proc2_$set_cleanup(4);
done:
  ml_$exclusion_stop(pbu_$exclusion_lock);
  if status.all <> status_$ok then begin
    setdown_unit := unit;
    pbu_$setdown(setdown_unit, ddf, setdown_status);
  end;
  return;
unlock:
  ml_$exclusion_stop(pbu_$exclusion_lock);
end;
