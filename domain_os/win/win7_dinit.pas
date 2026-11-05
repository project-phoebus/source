{ WIN7_$DINIT - the unit initialization entry.

  Image addresses:
    sau7  0x3C41ABF2  WIN7_$DINIT

  - A controller's first call sets it up: its mailbox area and command
    blocks get wired pages mapped at RAW_BUF (the first controller's
    call also the eventcounts and the 16 transfer windows), the area is
    mapped into the I/O map, the controller is given the
    initialization command and its parameters unless its status port
    says it is initialized, then win7_ctl_enable; the command blocks are
    linked into the free list, skipping a block that would cross a 4 KB
    boundary.
  - A drive's first call asks it for its parameters
    (win7_op_drive_params) under the controller's ML lock and waits up
    to 200 ticks for WIN7_$INT to record them.
  - With num_blocks 0 or less the geometry and the label information
    are returned.  The flags are a drive identifier by capacity.

  Returns:
    status_$ok: the drive is up
    status_$invalid_unit_number: a unit other than 0 or 1
    IOMAP_$MAP's, WIN_SEND_COMMAND's, WIN_SETUP_IOPB's or
      WIN_SETUP_MAILBOX's status: setting up the controller or the
      parameters' command failed
    status_$disk_controller_busy: the command port did not get ready
    status_$disk_controller_timeout: no interrupt in 200 ticks
    status_$logical_volume_not_found: the parameters' command failed

  Status stored: none.
}

function win7_$dinit(unit: integer; ctlr: pinteger;
                     var num_blocks: integer32;
                     out sec_per_track: pinteger; out num_heads: pinteger;
                     out pvlabel_info: win_$pvlabel_t;
                     out flags: pinteger): integer32;
  options(val_param);
label
  10, 20, 90;
var
  result: integer32;
  base: integer32;
  cb: win7_$ctlr_ptr_t;
  drive: win7_$drive_ptr_t;
  pad: integer32;
  iopb_pa: integer32;
  window: integer32;
  npages: integer;
  va: integer32;
  i: integer;
  pa: integer32;
  p: win7_$iopb_ptr_t;
  b: integer;
  regs: win7_$regs_ptr_t;
  deadline: integer32;
  wait_value: integer32;
  blocks: linteger;
  status: status_$t;
  param_8: integer32;
  start_cmd: integer32;
  ppns: win7_$ppn_list_t;
  vas: array[1..2] of integer32;
begin
  status.all := status_$ok;
  win7_mbox_size := 496;
  win7_iopb_size := 1224;
  win7_mbox_areas := win7_mbox_size + win7_mbox_size;
  base := integer32(addr(raw_buf));
  if (unit < 0) or (unit > 1) then begin
    result := status_$invalid_unit_number;
    goto 90;
  end;
  cb := win7_ctlrs[ctlr];
  drive := addr(cb^.drives[unit]);

  if not cb^.initialized then begin
    { the mailbox area and the command blocks, wired and mapped }
    if win7_first_dinit then begin
      ec_$init(win7_init_ec);
      ec_$init(win7_mbox_ec);
      if ((win7_mbox_areas + win7_iopb_size) & 1023) = 0 then
        pad := 0
      else
        pad := 1024 - ((win7_mbox_areas + win7_iopb_size) & 1023);
      cb^.map_base := win7_map_base_1;
      cb^.mbox := win7_$mbox_ptr_t(base);
      win7_mbox_pa := cb^.map_base;
      base := base + win7_mbox_areas;
      win7_iopb_base[ctlr] := base;
      iopb_pa := win7_mbox_areas + cb^.map_base;
      cb^.iopb_pa := iopb_pa;
      win7_window_base := pad + win7_iopb_size + iopb_pa;
      window := win7_window_base + win7_window_size;
      for win7_buf_index := 1 to win7_windows do begin
        win7_bufs[win7_buf_index] := window;
        window := window + win7_window_size;
      end;
      win7_buf_index := 1;
      npages := (win7_mbox_areas + win7_iopb_size + 1023) div 1024;
      wp_$calloc_list(npages, ppns);
      va := integer32(addr(raw_buf));
      for i := 1 to npages do begin
        mmu_$install(ppns[i], univ_ptr(va), 0, 16#16);
        mmu_$cache_inhibit_va(univ_ptr(va));
        va := va + 1024;
      end;
      win7_first_dinit := false;
    end
    else begin
      cb^.map_base := win7_map_base_2;
      cb^.mbox := win7_$mbox_ptr_t(base + win7_mbox_size);
      win7_mbox_pa := win7_mbox_pa + win7_mbox_size;
      win7_iopb_base[ctlr] :=
        ((base + win7_mbox_areas + win7_iopb_size) & 16#FFFFFC00) + 1024;
      cb^.iopb_pa := cb^.map_base;
      npages := (win7_iopb_size + 1023) div 1024;
      wp_$calloc_list(npages, ppns);
      va := ((base + win7_mbox_areas + win7_iopb_size) & 16#FFFFFC00) + 1024;
      for i := 1 to npages do begin
        mmu_$install(ppns[i], univ_ptr(va), 0, 16#16);
        mmu_$cache_inhibit_va(univ_ptr(va));
        va := va + 1024;
      end;
    end;
    for i := 0 to 123 do
      cb^.mbox^.all[i].all := nil;
    iomap_$map(3, cb^.map_base, ppns, vas, npages, 0, status);
    if status.all <> status_$ok then begin
      result := status.all;
      goto 90;
    end;

    { the initialization, unless the controller has had it }
    ml_$lock(cb^.lock);
    if (cb^.regs^.cmd & win7_status_initialized) = 0 then begin
      win_send_command(false, win7_ctl_initialize, unit, cb^, status);
      if status.all <> status_$ok then goto 10;
      win_send_command(false, 0, unit, cb^, status);
      if status.all <> status_$ok then goto 10;
      win_send_command(false, win7_init_param_1, unit, cb^, status);
      if status.all <> status_$ok then goto 10;
      win_send_command(false, win7_init_param_2, unit, cb^, status);
      if status.all <> status_$ok then goto 10;
      win_send_command(false, 0, unit, cb^, status);
      if status.all <> status_$ok then goto 10;
      b := rshft(win7_mbox_pa, 16) & 255;
      win_send_command(false, b, unit, cb^, status);
      if status.all <> status_$ok then goto 10;
      b := rshft(win7_mbox_pa, 8) & 255;
      win_send_command(false, b, unit, cb^, status);
      if status.all <> status_$ok then goto 10;
      b := win7_mbox_pa & 255;
      win_send_command(false, b, unit, cb^, status);
      if status.all <> status_$ok then goto 10;
      win_send_command(false, win7_mailboxes, unit, cb^, status);
      if status.all <> status_$ok then goto 10;
      win_send_command(false, win7_mailboxes, unit, cb^, status);
    end;
  10:
    ml_$unlock(cb^.lock);
    if status.all = status_$ok then
      win_send_command(false, win7_ctl_enable, unit, cb^, status);
    if status.all <> status_$ok then begin
      result := status.all;
      iomap_$unmap(3, win7_ctlrs[ctlr]^.map_base, npages);
      win7_map_total := win7_map_total - win7_map_size;
      io_$free_map(cb^.unit, status);
      goto 90;
    end;

    { the free list, without the blocks that cross a 4 KB boundary }
    cb^.free := win7_$iopb_ptr_t(win7_iopb_base[ctlr]);
    cb^.busy := nil;
    cb^.done := nil;
    win7_infos[ctlr][0].prev := nil;
    pa := cb^.iopb_pa;
    for i := 0 to 17 do begin
      if (pa & 16#FFFFF000) <> ((pa + 68) & 16#FFFFF000) then begin
        cb^.free := win7_$iopb_ptr_t(integer32(cb^.free) + 68);
        if i = 0 then begin
          win7_iopb_base[ctlr] := integer32(cb^.free);
          win7_infos[ctlr][1].prev := nil;
        end
        else if i = 17 then
          win7_infos[ctlr][i - 1].next := nil
        else begin
          win7_infos[ctlr][i - 1].next := cb^.free;
          win7_infos[ctlr][i + 1].prev := win7_infos[ctlr][i].prev;
        end;
        pa := pa + 68;
      end
      else begin
        p := cb^.free;
        p^.info := addr(win7_infos[ctlr][i]);
        p^.info^.phys := pa;
        pa := pa + 68;
        if i < 17 then begin
          win7_infos[ctlr][i + 1].prev := p;
          p^.info^.next := win7_$iopb_ptr_t(integer32(p) + 68);
          cb^.free := p^.info^.next;
        end
        else
          p^.info^.next := nil;
      end;
    end;
    cb^.free := win7_$iopb_ptr_t(win7_iopb_base[ctlr]);
    cb^.initialized := true;
  end;

  { the drive's parameters, once }
  if not drive^.valid then begin
    ml_$lock(cb^.lock);
    if status.all = status_$ok then begin
      win_setup_iopb(win7_op_drive_params, 0, unit, cb^, drive^, 0, nil,
                     param_8, status);
      if status.all = status_$ok then
        win_setup_mailbox(cb^, start_cmd, status);
    end;
    if status.all <> status_$ok then begin
      result := status.all;
      goto 20;
    end;
    wait_value := win7_init_ec.value + 1;
    regs := cb^.regs;
    if (regs^.cmd & win7_status_ready) = 0 then begin
      deadline := time_$clockh + 16;
      repeat
      until ((regs^.cmd & win7_status_ready) <> 0) or
            (time_$clockh > deadline);
      if (regs^.cmd & win7_status_ready) = 0 then begin
        result := status_$disk_controller_busy;
        goto 20;
      end;
    end;
    regs^.cmd := start_cmd;
    ml_$unlock(cb^.lock);
    win7_params_ok := false;
    if ec_$wait(addr(win7_init_ec), addr(time_$clockh_ec), addr(ec_$nil_ec),
                wait_value, time_$clockh + 200, 0) <> 0 then begin
      drive^.valid := false;
      result := status_$disk_controller_timeout;
      goto 90;
    end;
    if not win7_params_ok then begin
      drive^.valid := false;
      result := status_$logical_volume_not_found;
      goto 90;
    end;
  end;

  { the geometry, and the drive's identifier }
  if num_blocks <= 0 then begin
    sec_per_track := drive^.sectors;
    num_heads := drive^.heads;
    num_blocks := drive^.cyls * num_heads * sec_per_track;
    pvlabel_info.w_02 := drive^.precomp;
    pvlabel_info.w_00 := 0;
    pvlabel_info.w_04 := 0;
  end;
  blocks := drive^.sectors * drive^.heads * (drive^.cyls - 1);
  if blocks < 200000 then begin
    if num_heads = 7 then
      flags := win7_id_small_7_heads
    else
      flags := win7_id_small;
  end
  else if blocks < 400000 then
    flags := win7_id_200000
  else if blocks < 800000 then
    flags := win7_id_400000
  else if blocks < 2000000 then
    flags := win7_id_800000
  else
    flags := win7_id_2000000;
  if status.all <> status_$ok then
    result := status.all
  else
    result := status_$ok;
  goto 90;

20:
  ml_$unlock(cb^.lock);
90:
  win7_$dinit := result;
end;
