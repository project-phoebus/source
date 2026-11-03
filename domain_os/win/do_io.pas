{ WIN_$DO_IO - the driver's I/O entry: format a track, or run a chain of
  read and write requests.

  Image addresses:
    sau2  0x00E19776  WIN_$DO_IO
    sau4  0x0F81A0B0  WIN_$DO_IO
    sau5  0x00E19C2C  WIN_$DO_IO

  - A format request goes to win_$format_track.  Under the module's
    lock the ANSI form runs up to 24 passes of seek and transfer, a seek
    error or an equipment check re-initializing the drive.
  - The descriptor-list form builds one descriptor per request and gives
    one transfer command; data checks go to RETRY_DATA_CHECK.  Overruns
    are retried up to 500 times; a parity error PARITY_$CHK_IO confirms
    ends it.
  - The ring/disk form runs up to 12 passes, waiting 40 ticks for each
    transfer: a seek error re-initializes the drive (DISK_INIT), a drive
    time-out after the sixth pass too, overruns are retried up to 500
    times, a data check on a checksummed request ends the chain.

  Status stored (in the requests):
    the error: the current request, on failure
    -1: every request after it
}

%if win_descriptor_ctlr %then
procedure win_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                     in param_3: univ integer32; out result: boolean);
label
  80, 90;
var
  p: disk_$io_req_ptr_t;
  local_req: disk_$io_req_ptr_t;
  r: disk_$io_req_ptr_t;
  first: disk_$io_req_ptr_t;
  regs: win_$regs_ptr_t;
  ctlr: pinteger;
  lock: integer;
  op: integer;
  drive_word: pinteger;
  n: pinteger;
  status: integer32;
  retries: integer;
  dma_retries: integer;
  dc_retries: integer;
  parity_err: boolean;
begin
  p := addr(req);
  result := false;
  ctlr := 0;
  lock := win_units[0].lock;

  { a format request }
  op := p^.owner_op.op;
  if op = disk_$req_op_format_track then begin
    ml_$lock(lock);
    win_$format_track(vol, p^);
    goto 90;
  end;

  { the descriptors' drive word: the drive plus 8, plus 4 for a write;
    a write chain of more than one request is sorted first }
  drive_word := vol.dev_unit + 8;
  if op = disk_$req_op_write then begin
    if p^.next <> nil then begin
      local_req := p;
      disk_$sort(vol, local_req);
      p := local_req;
    end;
    ml_$lock(lock);
    win_cur_req := p;
    drive_word := drive_word + 4;
  end
  else begin
    ml_$lock(lock);
    win_cur_req := p;
  end;

  { one descriptor per request of the chain }
  regs := win_units[0].regs;
  n := 0;
  r := win_cur_req;
  while r <> nil do begin
    n := n + 1;
    with regs^.desc[n] do begin
      cyl := r^.daddr.cyl;
      head := r^.daddr.head;
      sector := r^.daddr.sector;
      phys := r^.phys;
      page := r^.ppn;
      drive := drive_word;
    end;
    r := r^.next;
  end;
  if win_cur_req^.owner_op.op = disk_$req_op_write then
    win_$cnt.xfer_op2 := win_$cnt.xfer_op2 + n
  else
    win_$cnt.xfer_other := win_$cnt.xfer_other + n;
  regs^.w_08 := 16#10;
  regs^.w_0a := 16#200;

  dma_retries := 0;
  retries := dma_retries;
  dc_retries := retries;
  first := win_cur_req;
  repeat
    win_cur_req := first;
    regs^.w_22 := 0;
    regs^.count := n;
    status := win_$command(ctlr, win_cmd_transfer);
    if status = status_$ok then
      goto 90;

    { what the status calls for }
    if status = status_$disk_controller_busy then begin
      retries := retries + 1;
      status := restore(ctlr, vol.dev_unit);
      if status = status_$ok then
        status := status_$disk_controller_busy;
    end
    else if status = status_$memory_parity_error_during_disk_write then begin
      parity_err := parity_$chk_io(rshft(win_cur_req^.phys, 10),
                                   win_cur_req^.ppn) <> 0;
      if parity_err then
        exit;
    end
    else if status = status_$disk_data_check then begin
      if win_cur_req^.owner_op.chksum then
        exit;
      if dc_retries >= 44 then
        exit;
      dc_retries := dc_retries + 1;
      status := retry_data_check(ctlr, vol.dev_unit, dc_retries);
      if status <> -1 then begin
        if status = status_$ok then begin
          { corrected: the requests after it go again }
          win_cur_req := win_cur_req^.next;
          status := -1;
        end;
        goto 80;
      end;
    end
    else if status = status_$dma_overrun then
      dma_retries := dma_retries + 1
    else begin
      retries := retries + 1;
      if retries = 3 then begin
        status := restore(ctlr, vol.dev_unit);
        if status <> status_$ok then
          goto 80;
      end;
    end;
  until (retries > 6) or (dma_retries > 500);
  if status = status_$ok then
    goto 90;

  { the failed request gets the status, the ones after it -1 }
80:
  if win_cur_req <> nil then begin
    disk_bptbl[win_cur_req^.owner_op.owner].io_pending := false;
    win_cur_req^.status.all := status;
    win_cur_req := win_cur_req^.next;
    while win_cur_req <> nil do begin
      win_cur_req^.status.all := -1;
      win_cur_req := win_cur_req^.next;
    end;
  end;

90:
  ml_$unlock(lock);
end;
%elseif win_ring_disk_ctlr %then

procedure win_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                     in param_3: univ integer32; out result: boolean);
label
  10;
var
  local_req: disk_$io_req_ptr_t;
  p: disk_$io_req_ptr_t;
  status: integer32;
  reinit_status: integer32;
  wait_val: integer32;
  unit: pinteger;
  lock: integer;
  dma_retries: integer;
  retries: integer;
  op: integer;
  scratch: pinteger;
  geometry: win_$geometry_t;
begin
  p := addr(req);
  result := false;
  unit := 0;
  lock := win_units[0].lock;

  { a format request }
  op := p^.owner_op.op;
  if op = disk_$req_op_format_track then begin
    ml_$lock(lock);
    win_$format_track(vol, p^);
  end
  else begin
    { a write chain is sorted first }
    if (op = disk_$req_op_write) and then (p^.next <> nil) then begin
      local_req := p;
      disk_$sort(vol, local_req);
      p := local_req;
    end;

    ml_$lock(lock);
    win_cur_req := p;
    win_dev_info := addr(vol);
    dma_retries := 0;

    for retries := 1 to 12 do begin
      { seek, and start the transfer }
10:   wait_val := win_unit_ec[0].value + 1;
      status := seek(unit, vol.dev_unit, win_cur_req^.daddr.cyl, false);
      if status = status_$ok then
        status := read_or_write_disk_record(vol, win_cur_req^)
      else if status = status_$disk_seek_error then begin
        reinit_status := disk_init(unit, vol.dev_unit, win_total_blocks,
                                   scratch, scratch, geometry, scratch);
        if reinit_status <> status_$ok then
          status := reinit_status;
        next;
      end;

      { wait for WIN_$INT, or 40 ticks }
      if status <= 0 then begin
        status := status_$ok;
        if ec_$wait(addr(win_unit_ec[0]),
                    ec_$eventcount_ptr_t(addr(time_$clockh)),
                    addr(ec_$nil_ec), wait_val, time_$clockh + 40,
                    0) <> 0 then begin
          win_flag := false;
          status := status_$disk_controller_timeout;
        end;
        if status = status_$ok then begin
          status := win_status;
          if status = status_$ok then
            exit;
        end;
      end;

      { what the status calls for }
      if status = status_$dma_overrun then begin
        dma_retries := dma_retries + 1;
        if dma_retries < 500 then
          goto 10;
        exit;
      end
      else if status = status_$drive_timed_out then begin
        if retries > 6 then begin
          ring_$send_null(unit);
          reinit_status := disk_init(unit, vol.dev_unit, win_total_blocks,
                                     scratch, scratch, geometry, scratch);
          if reinit_status <> status_$ok then
            status := reinit_status;
        end;
      end
      else if status = status_$disk_data_check then begin
        if win_cur_req^.owner_op.chksum then
          exit;
      end;
    end;

    { an error left fails the chain }
    if status <> status_$ok then begin
      disk_bptbl[win_cur_req^.owner_op.owner].io_pending := false;
      win_cur_req^.status.all := status;
      win_cur_req := win_cur_req^.next;
      while win_cur_req <> nil do begin
        win_cur_req^.status.all := -1;
        win_cur_req := win_cur_req^.next;
      end;
    end;
  end;

  ml_$unlock(lock);
end;
%else

procedure win_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                     in param_3: univ integer32; out result: boolean);
label
  10;
var
  local_req: disk_$io_req_ptr_t;
  p: disk_$io_req_ptr_t;
  status: integer32;
  wait_val: integer32;
  lock: integer;
  unit: pinteger;
  reinit_status: integer32;
  dma_retries: integer;
  op: integer;
%if memory_parity %then
  parity_err: boolean;
%endif
  retries: integer;
begin
  p := addr(req);
  result := false;
  unit := 0;
  lock := win_units[0].lock;

  { a format request }
  op := p^.owner_op.op;
  if op = disk_$req_op_format_track then begin
    ml_$lock(lock);
    win_$format_track(vol, p^);
  end
  else begin
    { a write chain is sorted first }
    if (op = disk_$req_op_write) and then (p^.next <> nil) then begin
      local_req := p;
      disk_$sort(vol, local_req);
      p := local_req;
    end;

    ml_$lock(lock);
    win_cur_req := p;
    win_dev_info := addr(vol);
    dma_retries := 0;

    for retries := 1 to 24 do begin
      { seek, and start the transfer }
10:   wait_val := win_unit_ec[0].value + 1;
      status := seek(unit, vol.dev_unit, win_cur_req^, false);
      if status = status_$ok then
        status := read_or_write_disk_record(unit)
      else if status = status_$disk_seek_error then begin
        reinit_status := win_$reinit_drive(unit, vol.dev_unit);
        if reinit_status <> status_$ok then
          status := reinit_status;
        next;
      end;

      { wait for WIN_$INT, or 8 ticks }
      if status <= 0 then begin
        status := status_$ok;
        if ec_$wait(addr(win_unit_ec[0]),
                    ec_$eventcount_ptr_t(addr(time_$clockh)),
                    addr(ec_$nil_ec), wait_val, time_$clockh + 8,
                    0) <> 0 then begin
          win_flag := false;
          win_status := status_$disk_controller_timeout;
        end;
        if status = status_$ok then begin
          status := win_status;
          if status = status_$ok then
            exit;
        end;
      end;

      { what the status calls for }
      if status = status_$dma_overrun then begin
        dma_retries := dma_retries + 1;
        if dma_retries < 500 then
          goto 10;
        exit;
      end
%if memory_parity %then
      else if status = status_$memory_parity_error_during_disk_write then begin
        parity_err := parity_$chk_io(rshft(win_cur_req^.phys, 10),
                                     win_cur_req^.ppn) <> 0;
        if parity_err then
          exit;
      end
%endif
      else begin
        if (status = status_$disk_data_check) and then
           (win_cur_req^.owner_op.chksum) then
          exit;
        if (status = status_$disk_not_ready) or else
           (status = status_$unknown_error_status_from_drive) or else
           (status = status_$disk_equipment_check) then
          discard(win_$reinit_drive(unit, vol.dev_unit));
      end;
    end;

    { an error left fails the chain }
    if status <> status_$ok then begin
      disk_bptbl[win_cur_req^.owner_op.owner].io_pending := false;
      win_cur_req^.status.all := status;
      win_cur_req := win_cur_req^.next;
      while win_cur_req <> nil do begin
        win_cur_req^.status.all := -1;
        win_cur_req := win_cur_req^.next;
      end;
    end;
  end;

  ml_$unlock(lock);
end;
%endif
