%if ct_atbus_qic02 %then
{ ct_transfer - read or write blocks of the cartridge tape.

  Image addresses:
    sau8  0x03C7A7CC  ct_transfer (module-local)

  - With the AT bus adapter (`ct_atbus_qic02'): the buffers' pages are
    checked and wired as the other form does; then, under the
    controller's lock, the read or write command is given again when
    ct_restart asks for it (DO_CTL_CMD, then CT_WAIT, 960 ticks), and
    each buffer goes through the DMA channel when the adapter shows
    ready: 512 bytes, or 1024 when it is the first half of a page whose
    second half follows.  An exception instead of ready is read
    (DO_CTL_CMD's read status, CT_WAIT, 480 ticks with quit).
  - After each DMA the count left gives the blocks done; a count not
    at a block's end ends the transfer.
  - nread is the blocks done; a failure ends the transfer state.

  Status stored:
    status_$ok: the blocks were moved
    ct_check_unit's result: the unit is not the caller's or is busy
    status_$ct_invalid_operation_count: npages is not 1..512
    status_$ct_illegal_drive_command: a write where the tape cannot be
      written
    ct_touch_pages's result: a buffer is not addressable
    status_$ct_bad_buffer_alignment: a buffer is not on a block
    status_$ct_invalid_buffer_address: a buffer is in the kernel's
      memory
    mst_$wire's status, its fail bit set: a page could not be wired
    the DMA's, the adapter's or the drive's status: the transfer failed
    status_$ct_dma_not_at_end_of_range: the DMA stopped within a block
}

procedure ct_transfer(unit: integer; in pages: univ ct_$page_list_t;
                      npages: integer; out nread: integer;
                      out status: status_$t); internal;
label
  9;
var
  n: pinteger;
  xfer_cmd: integer;
  reading: boolean;
  i: integer;
  k: integer;
  done: integer;
  nblocks: integer;
  len: integer;
  pa: integer32;
  timeout: integer32;
  page: integer32;
  last: integer32;
  dma_status: status_$t;
begin
  status.all := ct_check_unit(unit);
  if status.all <> 0 then
    return;
  if (npages <= 0) or else (npages > 512) then begin
    status.all := status_$ct_invalid_operation_count;
    return;
  end;
  n := npages;
  if not ct_reading and then not ct_write_ok then begin
    status.all := status_$ct_illegal_drive_command;
    return;
  end;
  status.all := ct_touch_pages(pages, n, ct_reading);
  if status.all <> 0 then
    return;
  { wire the buffers' pages }
  ct_io_count := 0;
  last := 0;
  for i := 1 to n do begin
    page := pages[i];
    if (page & 16#1FF) <> 0 then begin
      status.all := status_$ct_bad_buffer_alignment;
      ct_unwire_pages(ct_io_pages, ct_io_flags, ct_io_count);
      return;
    end;
    if linteger(page) >= linteger(addr(os_low)) then begin
      status.all := status_$ct_invalid_buffer_address;
      ct_unwire_pages(ct_io_pages, ct_io_flags, ct_io_count);
      return;
    end;
    if rshft(page, 10) <> rshft(last, 10) then begin
      ct_io_count := ct_io_count + 1;
      ct_io_pages[ct_io_count] := mst_$wire(page, status);
      if status.all <> 0 then begin
        ct_io_count := ct_io_count - 1;
        status.fail := true;
        ct_unwire_pages(ct_io_pages, ct_io_flags, ct_io_count);
        return;
      end;
      if (page & 16#3FF) <> 0 then
        ct_io_flags[ct_io_count] := true
      else
        ct_io_flags[ct_io_count] := false;
      last := page;
    end
    else begin
      ct_io_count := ct_io_count + 1;
      ct_io_pages[ct_io_count] := ct_io_pages[ct_io_count - 1];
      ct_io_flags[ct_io_count] := true;
      last := 0;
    end;
  end;

  { the command }
  if ct_reading then begin
    xfer_cmd := ct_cmd_read;
    ct_state := ct_state_read;
    ct_dma_dir := 0;
  end
  else begin
    xfer_cmd := ct_cmd_write;
    ct_state := ct_state_write;
    ct_dma_dir := 1;
  end;
  ct_cmd := xfer_cmd;
  k := 1;
  reading := ct_reading;
  done := 0;
  nread := done;
  ml_$lock(ct_dcte^.disk_error_que_hi);
  timeout := 60;
  if ct_restart then begin
    status.all := do_ctl_cmd(ct_cmd, ct_count_unlocked);
    if status.all = 0 then begin
      if ct_cmd = ct_cmd_read then
        ct_write_ok := false;
      if status.all = 0 then
        status.all := ct_wait(960, false);
    end;
    if xfer_cmd = ct_cmd_read then
      ct_state := ct_state_read
    else
      ct_state := ct_state_write;
    if status.all <> 0 then begin
      ct_regs^.dma_reset := 0;
      goto 9;
    end;
  end;
  ct_cmd := xfer_cmd;

  { the blocks, one DMA each }
  while k <= ct_io_count do begin
    if not ct_wait_ready(timeout, status) then begin
      if not ct_regs^.stat.no_exception then begin
        ct_restart := true;
        status.all := do_ctl_cmd(ct_cmd_read_status, ct_count_unlocked);
        if status.all = 0 then
          status.all := ct_wait(480, true);
      end;
      goto 9;
    end;
    ct_busy := true;
    ct_reading := reading;
    ct_wait_value := ct_ec.value + 1;
    ct_regs^.dma_go := 0;
    ct_regs^.ctl := ct_ctl_dma_enable;
    if not ct_io_flags[k] then begin
      pa := lshft(ct_io_pages[k], 10);
      if (k < ct_io_count) and then (ct_io_flags[k + 1] = true) then begin
        len := 1024;
        nblocks := 2;
      end
      else begin
        len := 512;
        nblocks := 1;
      end;
    end
    else begin
      pa := lshft(ct_io_pages[k], 10) + 512;
      len := 512;
      nblocks := 1;
    end;
    dma_$start_ncheck(ct_dma_channel, len, pa, ct_dma_dir, 0, status);
    if status.all = 0 then begin
      ct_dma_active := true;
      pbu_$enable_device(ct_pbu_unit, status);
      discard(ec_$wait(addr(ct_ec), addr(time_$clockh_ec),
                       addr(ec_$nil_ec), ct_wait_value,
                       time_$clockh + 8, 0));
    end;
    if status.all <> 0 then begin
      dma_$stop(ct_dma_channel, ct_residue, dma_status);
      goto 9;
    end;
    if ct_regs^.stat.dma_done then begin
      status.all := 0;
      dma_$stop(ct_dma_channel, ct_residue, dma_status);
      ct_dma_active := false;
    end
    else begin
      dma_status.all := ct_wait(120, false);
      if dma_status.all = 0 then begin
        dma_$stop(ct_dma_channel, ct_residue, dma_status);
        ct_dma_active := false;
      end
      else
        ct_regs^.dma_reset := 0;
    end;
    if ct_residue <> 0 then
      if ct_residue = 1023 then
        nblocks := nblocks - 2
      else if ct_residue = 511 then
        nblocks := nblocks - 1
      else begin
        nblocks := 0;
        status.all := status_$ct_dma_not_at_end_of_range;
      end;
    done := done + nblocks;
    if status.all <> 0 then
      goto 9;
    status := dma_status;
    if status.all <> 0 then
      goto 9;
    k := k + nblocks;
  end;
9:
  ml_$unlock(ct_dcte^.disk_error_que_hi);
  if (status.all = status_$ct_read_no_data_and_bot)
     or else (status.all = status_$ct_read_no_data)
     or else (status.all = status_$ct_read_no_data_and_eot) then
    ct_write_ok := true;
  if reading then
    discard(ct_touch_pages(pages, done, true));
  ct_unwire_pages(ct_io_pages, ct_io_flags, ct_io_count);
  ct_busy := false;
  nread := done;
  if status.all <> 0 then
    ct_state := ct_state_none;
end;
%else
{ ct_transfer - read or write blocks between the tape and a list of
  buffers.

  Image addresses:
    sau5  0x00E772BC  ct_transfer (module-local)

  - The direction is the module's ct_reading.  The buffers are touched
    and their 1 KB pages wired into the module's I/O list.
  - Under the controller's lock the read or write command goes in chunks
    of up to 32 blocks (480 ticks' wait each, the drive reset after a
    timeout); an error ends the chunks.
  - The list is then unwired and the count done returned.
  - The descriptors' word at +6 is cleared through the first descriptor
    only.

  Status stored:
    status_$ok: the blocks were transferred
    ct_check_unit's, ct_touch_pages's or ct_wait's result: those failed
    status_$ct_invalid_operation_count: a count outside 1..512
    status_$ct_illegal_drive_command: a write where writing may not
      begin
    status_$ct_bad_buffer_alignment: a buffer not 512-byte aligned
    status_$ct_invalid_buffer_address: a buffer at or above OS_LOW
    mst_$wire's status, with the fail bit: a page could not be wired
}

procedure ct_transfer(unit: integer; in pages: univ ct_$page_list_t;
                      npages: integer; out nread: integer;
                      out status: status_$t); internal;
var
  n: pinteger;
  xfer_cmd: integer;
  reading: boolean;
  i: integer;
  j: integer;
  k: integer;
  done: integer;
  chunk: pinteger;
  page: integer32;
  last: integer32;
begin
  status.all := ct_check_unit(unit);
  if status.all <> 0 then
    return;
  if (npages <= 0) or else (npages > 512) then begin
    status.all := status_$ct_invalid_operation_count;
    return;
  end;
  n := npages;
  if not ct_reading and then not ct_write_ok then begin
    status.all := status_$ct_illegal_drive_command;
    return;
  end;
  status.all := ct_touch_pages(pages, n, ct_reading);
  if status.all <> 0 then
    return;

  { wire the buffers' pages }
  ct_io_count := 0;
  last := 0;
  for i := 1 to n do begin
    page := pages[i];
    if (page & 16#1FF) <> 0 then begin
      status.all := status_$ct_bad_buffer_alignment;
      ct_unwire_pages(ct_io_pages, ct_io_flags, ct_io_count);
      return;
    end;
    if linteger(page) >= linteger(addr(os_low)) then begin
      status.all := status_$ct_invalid_buffer_address;
      ct_unwire_pages(ct_io_pages, ct_io_flags, ct_io_count);
      return;
    end;
    if rshft(page, 10) <> rshft(last, 10) then begin
      ct_io_count := ct_io_count + 1;
      ct_io_pages[ct_io_count] := mst_$wire(page, status);
      if status.all <> 0 then begin
        ct_io_count := ct_io_count - 1;
        status.fail := true;
        ct_unwire_pages(ct_io_pages, ct_io_flags, ct_io_count);
        return;
      end;
      if (page & 16#3FF) <> 0 then
        ct_io_flags[ct_io_count] := true
      else
        ct_io_flags[ct_io_count] := false;
      last := page;
    end
    else begin
      ct_io_count := ct_io_count + 1;
      ct_io_pages[ct_io_count] := ct_io_pages[ct_io_count - 1];
      ct_io_flags[ct_io_count] := true;
      last := 0;
    end;
  end;

  { the command, in chunks of up to 32 blocks }
  if ct_reading then begin
    xfer_cmd := ct_cmd_read;
    ct_state := ct_state_read;
  end
  else begin
    xfer_cmd := ct_cmd_write;
    ct_state := ct_state_write;
  end;
  ct_cmd := xfer_cmd;
  k := 1;
  reading := ct_reading;
  done := 0;
  nread := 0;
  ml_$lock(ct_dcte^.disk_error_que_hi);
  with ct_regs^ do
    while done < n do begin
      ct_reading := reading;
      chunk := 32;
      if n - done < 32 then
        chunk := n - done;
      for j := 1 to chunk do begin
        if not ct_io_flags[k] then
          desc[j].addr := lshft(ct_io_pages[k], 10)
        else
          desc[j].addr := lshft(ct_io_pages[k], 10) + 512;
        desc[1].w06 := 0;
        k := k + 1;
      end;
      count := chunk;
      w08 := 16#100;
      w0a := 0;
      go := 1;
      ct_wait_value := ct_ec.value + 1;
      cmd := xfer_cmd;
      if (status.all = 0) and then (ct_cmd = ct_cmd_read) then
        ct_write_ok := false;
      status.all := ct_wait(480, false);
      if (status.all = status_$ct_controller_timeout)
         or else (status.all = status_$ct_timeout_waiting_for_io) then
        reset_drive;
      done := done + chunk - ct_regs^.count;
      if status.all <> 0 then
        exit;
    end;
  ml_$unlock(ct_dcte^.disk_error_que_hi);

  if (status.all = status_$ct_read_no_data_and_bot)
     or else (status.all = status_$ct_read_no_data)
     or else (status.all = status_$ct_read_no_data_and_eot) then
    ct_write_ok := true;
  if reading then
    discard(ct_touch_pages(pages, done, true));
  ct_unwire_pages(ct_io_pages, ct_io_flags, ct_io_count);
  nread := done;
  if status.all <> 0 then
    ct_state := ct_state_none;
end;
%endif
