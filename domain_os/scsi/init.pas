{ SCSI_$INIT - set up a SCSI bus.

  Image addresses:
    sau9  0x3C43B788  SCSI_$INIT

  - The DCTE's I/O descriptor names the controller's window and the two
    interrupts (the controller's, the DMA port's); both get their
    routine, with the bus as its argument, and are enabled.
  - The 53C90's clock period, clock conversion factor, select time-out
    and the synchronous limits come from the system clock's frequency,
    each rounded twice to the nearest tenth.
  - The bus's eleven requests live in three pages of SCSI_CDB_PAGE;
    SCSI_PAGE's 33 pages are mapped at the bus's own pages until a
    transfer maps them.
  - A DCTE for a bus beyond the count crashes the system.
  - The request area is mapped three pages long; the crash path stops
    the exclusion lock.

  Returns:
    status_$ok: always
}

[section(os_init_proc, os_init_data)]
function scsi_$init(var dcte: dcte_t): integer32;
var
  bus: pinteger;
  cb: scsi_cb_ptr_t;
  regs: c90_regs_ptr_t;
  ccf: pinteger;
  area: scsi_req_ptr_t;
  req: scsi_req_ptr_t;
  offset: integer32;
  i: integer;
  n: integer;
  ppn: integer32;
  base: univ_ptr;
  va: integer32;
  status: status_$t;
  ppn_list: array[1..1] of integer32;
begin
  ml_$exclusion_init(scsi_$exclusion_lock);
  scsi_bus_count := 1;
  bus := dcte.cnum;
  if bus > scsi_bus_count - 1 then begin
    crash_system(status_$scsi_internal_error);
    ml_$exclusion_stop(scsi_$exclusion_lock);
  end
  else begin
    if scsi_init_count = 0 then
      scsi_init_ppn_owners;

    { The controller and its two interrupts. }
    cb := addr(scsi_$cb[bus]);
    scsi_$cb[bus].regs := scsi_io_desc_ptr_t(dcte.disk_dinit)^.regs;
    regs := cb^.regs;
    cb^.int_id := scsi_io_desc_ptr_t(dcte.disk_dinit)^.int_id;
    sysbus_$define_int(cb^.int_id, addr(scsi_$c90_int), cb);
    sysbus_$enable_device(cb^.int_id);
    cb^.dma_int_id := scsi_io_desc_ptr_t(dcte.disk_dinit)^.next^.int_id;
    sysbus_$define_int(cb^.dma_int_id, addr(scsi_$c90_dma), cb);
    sysbus_$enable_device(cb^.dma_int_id);

    { The clock period in ns, the clock conversion factor, the select
      time-out, the synchronous limits. }
    cb^.clock_ns :=
      (((100000000 div (time_$sys_freq div 1000)) + 5) div 10 + 5) div 10;
    ccf := ((20000 div cb^.clock_ns + 5) div 10 + 5) div 10;
    cb^.sel_timeout :=
      (((25000000 div ((cb^.clock_ns * (ccf * 8192)) div 1000)) + 5)
       div 10 + 5) div 10;
    cb^.max_offset := 15;
    cb^.min_period := 5 * cb^.clock_ns;
    cb^.max_period := 35 * cb^.clock_ns;

    { The controller's configuration: no slow cable, bus resets
      reported, no parity, no test mode, id 7; asynchronous. }
    regs^.config1.slow_cable := false;
    regs^.config1.no_reset_int := false;
    regs^.config1.parity_test := false;
    regs^.config1.parity_enable := false;
    regs^.config1.chip_test := false;
    regs^.config1.bus_id := scsi_host_id;
    regs^.ccf.ccf := ccf;
    regs^.r18.sync.period := 5;
    regs^.r1c.sync.offset := 0;
    regs^.config2.bit_4 := false;
    regs^.config2.bit_3 := false;
    regs^.config2.bit_2 := false;
    regs^.config2.bit_1 := false;
    regs^.config2.bit_0 := false;

    { The request area's pages. }
    area := addr(scsi_cdb_page[bus]);
    offset := 0;
    for i := 0 to 2 do begin
      if mmap_$alloc_free(ppn_list, 1) = 0 then
        crash_system(status_$scsi_too_many_wired_pages);
      mmu_$install(ppn_list[1], univ_ptr(integer32(area) + offset), 0, 16#16);
      offset := offset + 1024;
    end;

    { SCSI_PAGE's pages, and their map entries. }
    base := addr(scsi_page);
    va := integer32(base);
    ppn := mmu_$vtop(integer32(addr(scsi_$cb)), status);
    if status.all <> status_$ok then
      crash_system(status_$scsi_internal_error);
    for i := 1 to scsi_max_pages do begin
      mmu_$install(ppn, univ_ptr(va), 0, 16#16);
      cb^.pmape[i] := mmu_$get_pmape_addr(univ_ptr(va));
      va := va + 1024;
      ppn := ppn + 1;
    end;

    { The free list. }
    cb^.free_count := 11;
    cb^.free_head := area;
    req := area;
    req^.next := scsi_req_ptr_t(integer32(req) + 178);
    n := 10;
    while n > 0 do begin
      req := req^.next;
      req^.next := scsi_req_ptr_t(integer32(req) + 178);
      n := n - 1;
    end;
    req^.next := nil;
    cb^.free_tail := req;

    cb^.msg[0] := scsi_msg_nop;
    cb^.msg_count := 1;
    cb^.msg_index := 0;
    cb^.send_atn := false;
    ec_$init(cb^.free_ec);
    scsi_$present := true;
    scsi_init_count := scsi_init_count + 1;
  end;
  scsi_$init := status_$ok;
end;
