{ WIN7_$CINIT - a mailbox controller's initialization.

  Image addresses:
    sau7  0x3C438AE0  WIN7_$CINIT

  - A controller whose record is set up already returns at once; the
    result is then not stored.
  - The record takes the DCTE's ports, vector, lock and unit; the
    controller is reset and must show its command port ready.  Its DMA
    channel goes into cascade mode, and an I/O map region is taken for
    its mailbox area and command blocks: the first controller's also
    for the 16 transfer windows (16#44000 bytes more).
  - A controller that answers is registered with DISK_$REGISTER;
    another's DMA channel and unit are given back.

  Returns:
    status_$ok: the controller is set up
    status_$io_controller_not_in_system: IO_$ACQUIRE failed, or the
      controller did not answer
    IO_$MAP_CSR's, IO_$ENABLE_DEVICE's, DMA_$START_NCHECK's or
      IO_$ALLOC_MAP's status: setting up the controller failed

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
function win7_$cinit(var dcte: win_$dcte_t): integer32;
label
  50;
var
  result: integer32;
  dcte_addr: univ_ptr;
  cnum: integer;
  cb: win7_$ctlr_ptr_t;
  dma_on: boolean;
  i: integer;
  unit: io_$unit_num_t;
  delay: integer32;
  regs: win7_$regs_ptr_t;
  ready: boolean;
  j: integer32;
  k: integer;
  st: integer;
  pad: integer32;
  status: status_$t;
  residue: integer32;
  jt: univ_ptr;
begin
  dcte_addr := addr(dcte);
  cnum := dcte.cnum;
  win7_mbox_size := 496;
  win7_iopb_size := 1224;
  win7_mbox_areas := win7_mbox_size + win7_mbox_size;
  cb := win7_ctlrs[cnum];
  dma_on := false;
  if cb^.initialized then
    return;

  for i := 0 to 1 do begin
    cb^.drives[i].stats.reads := 0;
    cb^.drives[i].stats.writes := 0;
    cb^.drives[i].stats.w_08 := 0;
    cb^.drives[i].stats.timeouts := 0;
    cb^.drives[i].stats.seek_errors := 0;
    cb^.drives[i].stats.equip_checks := 0;
    cb^.drives[i].stats.not_ready := 0;
    cb^.drives[i].stats.data_checks := 0;
    cb^.drives[i].stats.late_completions := 0;
  end;
  cb^.regs := win7_$regs_ptr_t(dcte.req.csr.va);
  cb^.vector := dcte.req.int.id.vector;
  cb^.csr_pa := dcte.req.csr.pa;
  cb^.lock := dcte.lock;

  io_$acquire(dcte.req, addr(win7_$int), dcte_addr, unit, status);
  if status.all <> status_$ok then begin
    result := status_$io_controller_not_in_system;
    goto 50;
  end;
  io_$map_csr(dcte.req, status);
  if status.all = status_$ok then begin
    ec_$init(win_unit_ec[cnum]);

    { the reset, then the command port ready 16 times }
    delay := 0;
    status.all := status_$io_controller_not_in_system;
    regs := cb^.regs;
    regs^.ctl := win7_ctl_reset;
    for i := 0 to 299 do
      delay := delay + 1;
    regs^.ctl := win7_ctl_run;
    for j := 0 to 4999999 do
      delay := delay + 1;
    ready := true;
    for k := 0 to 15 do begin
      st := regs^.cmd & 16#F0;
      if st <> win7_status_ready then begin
        ready := false;
        exit;
      end;
    end;
    if ready then begin
      io_$enable_device(unit, status);
      if status.all = status_$ok then begin
        dma_$start_ncheck(cb^.dma_channel, 0, 0, 1, 4, status);
        if status.all = status_$ok then begin
          dma_on := true;

          { the I/O map region: the mailbox areas and command blocks,
            and once the windows }
          if win7_first_cinit then begin
            win7_first_cinit := false;
            win7_map_total := 0;
            if ((win7_mbox_areas + win7_iopb_size) & 1023) = 0 then
              pad := 0
            else
              pad := 1024 - ((win7_mbox_areas + win7_iopb_size) & 1023);
            win7_map_size := pad + win7_mbox_areas + win7_iopb_size +
                             16#44000;
            win7_map_total := win7_map_total + win7_map_size;
            win7_map_left := 16#7FC00 - win7_map_total;
            win7_map_base_1 := io_$alloc_map(unit, win7_map_size, false, 0,
                                             status);
          end
          else begin
            if (win7_iopb_size & 1023) = 0 then
              pad := 0
            else
              pad := 1024 - (win7_iopb_size & 1023);
            win7_map_size := pad + win7_iopb_size;
            win7_map_total := win7_map_total + win7_map_size + 1024;
            win7_map_left := 16#7FC00 - win7_map_total;
            win7_map_base_2 := io_$alloc_map(unit, win7_map_size, false, 0,
                                             status);
          end;
        end;
      end;
    end;
  end;

  result := status.all;
  if status.all = status_$ok then begin
    cb^.unit := unit;
    if st = win7_status_ready then begin
      jt := addr(win7_jump_table);
      discard(disk_$register(0, dcte.cnum, win_unit_bits, dcte.lock, jt));
    end;
  end
  else begin
    if dma_on then
      dma_$stop(cb^.dma_channel, residue, status);
    io_$release(unit, status);
  end;
50:
  win7_$cinit := result;
end;
