{ WIN8_$DO_IO - the driver's I/O entry: format a track, read the
  manufacturer's bad spots, or run a chain of read and write requests.

  Image addresses:
    sau7  0x3C41CF02  WIN8_$DO_IO
    sau8  0x03C1A556  WIN8_$DO_IO

  - Under the controller's ML lock.  A chain runs in runs of
    contiguous requests, up to win_max_count sectors each.  A read goes
    from the disk to the controller's buffer, then a sector at a time
    through WIN_PAGE into the requests' pages; a write goes the other
    way.  Each run waits for the controller's
    interrupt, 40 ticks at most.
  - An equipment check retries the run up to five times.  A parity error
    PARITY_$CHK_IO reports during a write fails the chain at that
    sector.
  - After the chain the controller must be idle; a completion byte
    still waiting is read and counted, anything else crashes the system.

  Status stored (in the requests):
    the error: the first request not done, on failure
    -1: every request after it
}

procedure win8_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                      in param_3: univ integer32; out result: boolean);
label
  10, 50, 60, 70, 80, 90;
var
  dcte: win_$dcte_ptr_t;
  local_req: disk_$io_req_ptr_t;
  first: disk_$io_req_ptr_t;
  p: disk_$io_req_ptr_t;
  r: disk_$io_req_ptr_t;
  q: disk_$io_req_ptr_t;
  regs: win_$regs_ptr_t;
  page_va: univ_ptr;
  op: integer;
  count: integer;
  retries: integer;
  n_done: integer;
  done_total: integer;
  parity_at: integer;
  parity_err: boolean;
  hit: boolean;
  hung: boolean;
  wait_val: integer32;
  ppn: integer32;
  status: integer32;
  err: integer32;
  i: integer;
begin
  result := false;
  status := status_$ok;
  err := status;
  done_total := 0;
  dcte := win_units[0].dcte;

  { a format request, a bad-spot read }
  op := req.owner_op.op;
  if op = disk_$req_op_format_track then begin
    ml_$lock(dcte^.lock);
    win_$format_track(vol, req);
    goto 90;
  end;
  local_req := addr(req);
  if op = disk_$req_op_format then begin
    ml_$lock(dcte^.lock);
    win_$read_mfg_badspots(vol, req);
    goto 80;
  end;

  { a write chain is sorted first }
  if (local_req^.owner_op.op = disk_$req_op_write) and then
     (local_req^.next <> nil) then
    disk_$sort(vol, local_req);
  p := local_req;
  regs := win_units[0].regs;
  ml_$lock(dcte^.lock);
  page_va := addr(win_page);
  op := p^.owner_op.op;

  repeat
    { the run: the requests that follow on the disk }
    count := 1;
    retries := 0;
    r := p;
    while r^.next <> nil do begin
      if count >= win_max_count then
        exit;
      if r^.header.abs_daddr + r^.flags <>
         disk_$io_req_ptr_t(r^.next)^.header.abs_daddr then
        exit;
      count := count + 1;
      r := r^.next;
    end;
    wait_val := win_unit_ec[vol.dev_info^.controller].value + 1;

10: n_done := 0;
    win_cmd.count := count;
    win_count := count;
    parity_at := 0;
    parity_err := false;
    win_cmd.unit := vol.dev_unit;
    case op of
      disk_$req_op_read: begin
        regs^.ctl := win_ctl_int_on;
        status := win_$send_command(win_cmd_read, p^.daddr.cyl,
                                    p^.daddr.head, p^.daddr.sector);
        if status = status_$ok then
          win_stats[vol.dev_unit].stats.reads :=
            win_stats[vol.dev_unit].stats.reads + count
        else
          regs^.ctl := win_ctl_int_off;
      end;
      disk_$req_op_write: begin
        { the run's sectors into the controller's buffer }
        first := p;
        if win_$send_command(win_cmd_write_buffer, 0, 0, 0) <> status_$ok then
          regs^.ctl := win_ctl_int_off
        else
          for i := 1 to count do begin
            status := win_$wait_phase(win_phase_data_out);
            if status <> status_$ok then
              goto 80;
            mmu_$set_pmape(page_va, win_page_pmape, p^.ppn);
            win_buf := page_va;
            ppn := win_$phys_addr_t(p^.phys).ppn;
            parity_$set_state(0, ppn, p^.ppn);
            win_$fill_ctl_buf(addr(p^.header), win_buf, regs);
            hit := parity_$chk_io(0, ppn, p^.ppn) <> 0;
            if hit and not parity_err then begin
              parity_err := true;
              parity_at := i - 1;
              err := status_$memory_parity_error_during_disk_write;
            end;
            win_stats[vol.dev_unit].stats.writes :=
              win_stats[vol.dev_unit].stats.writes + 1;
            p := p^.next;
          end;

        { then to the disk }
        status := win_$check_status(vol.dev_unit);
        if status <> status_$ok then
          goto 50;
        regs^.ctl := win_ctl_int_on;
        status := win_$send_command(win_cmd_write, first^.daddr.cyl,
                                    first^.daddr.head, first^.daddr.sector);
      end;
      otherwise begin
        status := status_$unknown_error_status_from_drive;
        goto 80;
      end;
    end;
    if status <> status_$ok then
      goto 50;

    { the controller's interrupt }
    if ec_$wait(addr(win_unit_ec[vol.dev_info^.controller]),
                ec_$eventcount_ptr_t(addr(time_$clockh)),
                addr(ec_$nil_ec), wait_val, time_$clockh + 40, 0) <> 0 then
    begin
      status := status_$disk_controller_timeout;
      win_stats[vol.dev_unit].stats.timeouts :=
        win_stats[vol.dev_unit].stats.timeouts + 1;
      goto 80;
    end;
    status := win_$check_status(vol.dev_unit);
    if status <> status_$ok then
      if win_count <= 0 then
        goto 60;

    if op = disk_$req_op_write then begin
      if parity_err then
        goto 70;
      n_done := win_count;
      err := status_$ok;
      goto 60;
    end;

    { a read: the sectors done, from the controller's buffer }
    win_hdr := addr(p^.header);
    err := status;
    win_cmd.count := win_count;
    status := win_$send_command(win_cmd_read_buffer, 0, 0, 0);
    if status <> status_$ok then
      goto 60;
    for i := 1 to win_count do begin
      status := win_$wait_phase(win_phase_data_in);
      if status <> status_$ok then
        goto 80;
      mmu_$set_pmape(page_va, win_page_pmape, p^.ppn);
      win_buf := page_va;
      n_done := n_done + 1;
      win_$empty_ctl_buf(regs, addr(p^.header), win_buf);
      p := p^.next;
    end;
    status := win_$check_status(vol.dev_unit);
    goto 60;

    { a failed command or transfer }
50: if parity_err then begin
      if win_count < parity_at then begin
        n_done := win_count;
        err := status;
      end
      else
70:   begin
        n_done := parity_at;
        err := status_$memory_parity_error_during_disk_write;
      end;
    end
    else if (status = status_$disk_equipment_check) and (retries < 5) then
    begin
      retries := retries + 1;
      p := first;
      goto 10;
    end;

60: done_total := done_total + n_done;
  until (err <> status_$ok) or ((p = nil) or parity_err) or
        (status <> status_$ok);

  { the controller must be idle }
80: regs := win_units[0].regs;
  hung := win_$wait_phase(win_phase_idle) <> status_$ok;
  if hung then
    if regs^.status = win_status_completion then begin
      status := win_$check_status(vol.dev_unit);
      if status = status_$ok then
        win_stats[vol.dev_unit].stats.late_completions :=
          win_stats[vol.dev_unit].stats.late_completions + 1;
    end
    else
      crash_system(status_$drive_timed_out);

  { a failed chain: the error to the first request not done, -1 to the
    rest, and the counts taken back }
  if (status <> status_$ok) or (err <> status_$ok) then begin
    q := local_req;
    disk_bptbl[q^.owner_op.owner].io_pending := false;
    for i := 2 to done_total do
      q := q^.next;
    if err <> status_$ok then
      q^.status.all := err
    else
      q^.status.all := status;
    repeat
      case q^.owner_op.op of
        disk_$req_op_read: begin
          win_stats[vol.dev_unit].stats.reads :=
            win_stats[vol.dev_unit].stats.reads - 1;
        end;
        disk_$req_op_write: begin
          win_stats[vol.dev_unit].stats.writes :=
            win_stats[vol.dev_unit].stats.writes - 1;
        end;
      end;
      q := q^.next;
      if q <> nil then
        q^.status.all := -1;
    until q = nil;
  end;

90: ml_$unlock(dcte^.lock);
end;
