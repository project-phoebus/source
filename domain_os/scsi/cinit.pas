%if scsi_mailbox_ctlr %then
{ SCSI_$CINIT - initialize the SCSI controller.

  Image addresses:
    sau7  0x3C43FD84  SCSI_$CINIT

  - With the mailbox host adapter: the adapter's CSR page is mapped, the
    adapter reset (it must show no failure, then ready with a good
    self-test), the bus reset, its interrupt taken (IO_$ACQUIRE) and the
    page owners' table set up (scsi_init_ppn_owners).
  - Its DMA channel is put in cascade mode, an I/O map region of 3 KB
    taken for the mailbox area and the command blocks, the pages
    allocated, cache-inhibited, mapped and cleared, and the adapter
    initialized with the area's bus address and 64 mailboxes each way,
    unless it shows itself initialized already.
  - SCSI_$PRESENT tells whether the bus is up; on a failure after
    IO_$ACQUIRE the unit is released.

  Returns:
    0: the adapter is up
    status_$io_controller_not_in_system: it showed a failure after the
      reset
    status_$scsi_hardware_failure: it did not answer the reset as it
      should
    status_$scsi_hardware_timeout: its command port was not ready in
      time, or it did not initialize
    status_$scsi_internal_error: no free page for the area
    status_$scsi_bad_parameter: it rejected an initialization byte
    the callees' statuses: those failed

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
function scsi_$cinit(var dcte: dcte_t): integer32;
label
  8, 9;
type
  req_ptr_t = ^io_$acquire_rec_t;
  addr_t = record
    case integer of
      1: (all: integer32);
      2: (b: array[0..3] of char);
  end;
var
  cb: scsi_mb_cb_ptr_t;
  req: req_ptr_t;
  regs: scsi_mb_regs_ptr_t;
  st: status_$t;
  rel_st: status_$t;
  acquired: boolean;
  unit: io_$unit_num_t;
  first_stat: integer;
  spin: integer;
  i: integer;
  len: integer32;
  va: integer32;
  off: integer32;
  mbox_pa: addr_t;
  vpn: array[1..1] of integer32;
  init: array[1..10] of integer;
begin
  ml_$exclusion_init(scsi_$exclusion_lock);
  cb := addr(scsi_$cb[dcte.cnum]);
  req := req_ptr_t(dcte.disk_dinit);
  io_$map_csr(req^, st);
  if st.all <> 0 then
    goto 9;
  cb^.regs := scsi_mb_regs_ptr_t(req^.csr.va);
  cb^.csr_pa := req^.csr.pa;
  cb^.map_bus := req^.bus;
  ec_$init(cb^.ec);
  acquired := false;
  regs := cb^.regs;
  first_stat := regs^.cmd;

  { reset the adapter and the bus }
  regs^.ctl := scsi_mb_ctl_reset;
  spin := 0;
  repeat
    spin := spin + 1;
  until spin = 1000;
  if (regs^.cmd & scsi_mb_stat_failed) <> 0 then begin
    regs^.ctl := scsi_mb_ctl_off;
    st.all := status_$io_controller_not_in_system;
    goto 9;
  end;
  regs^.ctl := scsi_mb_ctl_off;
  discard(scsi_wait_cmd_ready(cb^));
  for i := 1 to 17 do
    if (regs^.cmd & scsi_mb_stat_ready) = 0 then begin
      st.all := status_$scsi_hardware_failure;
      goto 9;
    end;
  if regs^.int <> 1 then begin
    st.all := status_$scsi_hardware_failure;
    goto 9;
  end;
  regs^.ctl := scsi_mb_ctl_bus_reset;
  discard(scsi_wait_cmd_ready(cb^));

  io_$acquire(req^, addr(scsi_$int), addr(cb^), unit, st);
  if st.all <> 0 then
    goto 9;
  acquired := true;
  cb^.unit := unit;
  regs^.ctl := scsi_mb_ctl_off;
  cb^.mbox_count := scsi_mb_mailboxes;
  scsi_init_ppn_owners;
  regs^.ctl := scsi_mb_ctl_off;
  regs^.ctl := scsi_mb_ctl_dma;
  if scsi_wait_cmd_ready(cb^) then
    goto 8;
  dma_$start_ncheck(1, 0, 0, 0, 4, st);
  if st.all <> 0 then
    goto 9;

  { the mailbox area and the command blocks, through the I/O map }
  len := 3072;
  cb^.map_base := io_$alloc_map(cb^.unit, len, false, 0, st);
  if st.all <> 0 then
    goto 9;
  cb^.scb_base := cb^.map_base + 1024;
  if mmap_$alloc_free(vpn, 1) <> 1 then begin
    st.all := status_$scsi_internal_error;
    goto 9;
  end;
  mmu_$install(vpn[1], addr(scsi_mailboxes), 0, 16#16);
  mmu_$cache_inhibit_va(addr(scsi_mailboxes));
  iomap_$map(cb^.map_bus, cb^.map_base, vpn, 0, 1, 0, st);
  if st.all <> 0 then
    goto 9;
  va := integer32(addr(scsi_scbs));
  off := 0;
  for i := 1 to 2 do begin
    if mmap_$alloc_free(vpn, 1) <> 1 then begin
      st.all := status_$scsi_internal_error;
      goto 9;
    end;
    mmu_$install(vpn[1], univ_ptr(va), 0, 16#16);
    mmu_$cache_inhibit_va(univ_ptr(va));
    iomap_$map(cb^.map_bus, cb^.scb_base + off, vpn, 0, 1, 0, st);
    if st.all <> 0 then
      goto 9;
    va := va + 1024;
    off := off + 1024;
  end;
  mbox_pa.all := cb^.map_base;
  os_$data_zero(scsi_mailboxes, 512);
  os_$data_zero(scsi_scbs, 2048);
  if (regs^.cmd & scsi_mb_stat_initialized) <> 0 then
    goto 9;

  { the initialization command }
  init[1] := scsi_mb_cmd_initialize;
  init[2] := scsi_host_id;
  init[3] := scsi_mb_bus_on;
  init[4] := scsi_mb_bus_off;
  init[5] := 0;
  init[6] := ord(mbox_pa.b[1]);
  init[7] := ord(mbox_pa.b[2]);
  init[8] := ord(mbox_pa.b[3]);
  init[9] := scsi_mb_mailboxes;
  init[10] := scsi_mb_mailboxes;
  for i := 1 to 10 do begin
    if scsi_wait_cmd_ready(cb^) then
      goto 8;
    regs^.cmd := init[i];
    if (regs^.cmd & scsi_mb_stat_rejected) <> 0 then begin
      st.all := status_$scsi_bad_parameter;
      goto 9;
    end;
  end;
  if scsi_wait_cmd_ready(cb^) then
    goto 8;
  regs^.ctl := scsi_mb_ctl_run;
  spin := 0;
  repeat
    spin := spin + 1;
  until spin = 20000;
  if scsi_wait_cmd_ready(cb^) then
    goto 8;
  if (regs^.cmd & scsi_mb_stat_initialized) = 0 then
    goto 8;
  cb^.mbox_count := 192;
  cb^.int_count := 0;
  io_$enable_device(cb^.unit, st);
  goto 9;
8:
  st.all := status_$scsi_hardware_timeout;
9:
  scsi_$present := st.all = 0;
  if (st.all <> 0) and acquired then
    io_$release(unit, rel_st);
  scsi_$cinit := st.all;
end;
%else
{ SCSI_$CINIT - initialize the SCSI controller.

  Image addresses:
    sau2  0x00E34F04  SCSI_$CINIT
    sau9  0x3C43BAB0  SCSI_$CINIT

  - A stub on every SAU, the SAU9's driver too: its bus is set up by
    SCSI_$INIT, the DCTE's routine.

  Returns:
    status_$io_controller_not_in_system: always

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
function scsi_$cinit: integer32;
begin
  scsi_$cinit := status_$io_controller_not_in_system;
end;
%endif
