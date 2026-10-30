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
