{ WIN7_$DO_IO - the driver's I/O entry: format a track or the drive, or
  run a chain of read and write requests.

  Image addresses:
    sau7  0x3C41BC86  get_buffer (nested)
    sau7  0x3C41BD14  wait_buffer (nested)
    sau7  0x3C41BD7C  free_buffer (nested)
    sau7  0x3C41BD98  WIN7_$DO_IO

  Assume we're called with the controller's ML lock free; the routine
  holds it throughout.
  - The process's record for the drive is cleared and its pending flag
    set; the requests complete through WIN7_$INT.
  - A chain is sent in runs of up to 16 contiguous requests (a write
    chain sorted first), each run in a window of its own and one command
    block.
  - A failure marks the process's record, clears its pending flag and
    gives the chain's requests the status, takes the block back to the
    free list and frees its window.
  - result is true when the requests were sent or failed.

  Status stored (in the requests):
    status_$ok: cleared before a request is sent
    status_$unknown_error_status_from_drive: an operation other than a
      read, a write or a format
    WIN_SETUP_IOPB's, WIN_SETUP_MAILBOX's or WIN_SEND_COMMAND's status:
      a run could not be sent
}

procedure win7_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                      in param_3: univ integer32; out result: boolean);
label
  50, 90;
var
  cb: win7_$ctlr_ptr_t;
  drive: win7_$drive_ptr_t;
  status: status_$t;
  token: pinteger;
  op: integer;
  cmd: integer;
  count: integer;
  p: disk_$io_req_ptr_t;
  local_req: disk_$io_req_ptr_t;
  n: integer;
  info: win7_$info_ptr_t;
  buf: integer32;
  start: win7_$start_t;
  param_8: integer32;

  { get_buffer - take a window from the pool, if one is free. }
  function get_buffer(out buf: integer32): boolean;
  var
    token: pinteger;
    ok: boolean;
  begin
    token := ml_$spin_lock(win7_ctlrs[vol.dev_info^.controller]^.spin);
    if win7_buf_index = win7_windows + 1 then
      ok := false
    else begin
      buf := win7_bufs[win7_buf_index];
      win7_bufs[win7_buf_index] := 0;
      win7_buf_index := win7_buf_index + 1;
      ok := true;
    end;
    ml_$spin_unlock(win7_ctlrs[vol.dev_info^.controller]^.spin, token);
    get_buffer := ok;
  end;

  { wait_buffer - wait for a window, 15 ticks at a time; after 240 ticks
    the system crashes. }
  procedure wait_buffer(out buf: integer32);
  var
    deadline: integer32;
    status: status_$t;
  begin
    deadline := time_$clockh + 240;
    repeat
      if get_buffer(buf) then
        exit;
      time_$wait(time_$relative, win7_window_wait, status);
      if time_$clockh > deadline then
        crash_system(status_$disk_controller_timeout);
    until false;
  end;

  { free_buffer - give a window back to the pool. }
  procedure free_buffer(buf: integer32);
  begin
    win7_buf_index := win7_buf_index - 1;
    win7_bufs[win7_buf_index] := buf;
  end;

begin
  cb := win7_ctlrs[vol.dev_info^.controller];
  drive := addr(cb^.drives[vol.dev_unit]);
  ml_$lock(cb^.lock);
  status.all := status_$ok;
  result := false;

  { the process's record for the drive }
  token := ml_$spin_lock(cb^.spin);
  cb^.procs[req.owner_op.owner][vol.dev_unit].count := 0;
  cb^.procs[req.owner_op.owner][vol.dev_unit].flags :=
    cb^.procs[req.owner_op.owner][vol.dev_unit].flags - [15];
  cb^.procs[req.owner_op.owner][vol.dev_unit].flags :=
    cb^.procs[req.owner_op.owner][vol.dev_unit].flags - [14];
  disk_bptbl[req.owner_op.owner].io_pending := true;
  ml_$spin_unlock(cb^.spin, token);

  op := req.owner_op.op;
  case op of
    disk_$req_op_format_track, disk_$req_op_format: begin
      if op = disk_$req_op_format_track then
        cmd := win7_op_format_track
      else
        cmd := win7_op_format;
      count := 1;
      req.status.all := status_$ok;
      win7_cur_req := addr(req);
      if not get_buffer(buf) then
        wait_buffer(buf);
      win_setup_iopb(cmd, buf, vol.dev_unit, cb^, drive^, count,
                     win7_cur_req, param_8, status);
      if status.all <> status_$ok then goto 50;
      win_setup_mailbox(cb^, start.l, status);
      if status.all <> status_$ok then goto 50;
      win_send_command(true, start.lo, vol.dev_unit, cb^, status);
    end;

    disk_$req_op_read, disk_$req_op_write: begin
      if op = disk_$req_op_write then
        cmd := win7_op_write
      else
        cmd := win7_op_read;
      p := addr(req);
      if (req.owner_op.op = disk_$req_op_write) and (req.next <> nil) then
      begin
        local_req := p;
        disk_$sort(vol, local_req);
        p := local_req;
      end;
      repeat
        { a run of contiguous requests, up to 16, in one window }
        if not get_buffer(buf) then
          wait_buffer(buf);
        n := 1;
        win7_ppns[1] := p^.ppn;
        win7_pages[1] := win_$phys_addr_t(p^.phys).ppn;
        p^.status.all := status_$ok;
        win7_cur_req := p;
        while win7_cur_req^.next <> nil do begin
          if n >= 16 then
            exit;
          if win7_cur_req^.header.abs_daddr + win7_cur_req^.flags <>
             disk_$io_req_ptr_t(win7_cur_req^.next)^.header.abs_daddr then
            exit;
          n := n + 1;
          win7_ppns[n] := disk_$io_req_ptr_t(win7_cur_req^.next)^.ppn;
          win7_pages[n] :=
            win_$phys_addr_t(disk_$io_req_ptr_t(win7_cur_req^.next)^.phys).ppn;
          win7_cur_req^.status.all := status_$ok;
          win7_cur_req := win7_cur_req^.next;
        end;
        count := n;
        win_setup_iopb(cmd, buf, vol.dev_unit, cb^, drive^, count, p,
                       param_8, status);
        if status.all = status_$ok then begin
          win_setup_mailbox(cb^, start.l, status);
          if status.all = status_$ok then begin
            win_send_command(true, start.lo, vol.dev_unit, cb^, status);
            if status.all = status_$ok then begin
              if (win7_cur_req^.next = nil) or
                 ((win7_cur_req = p) and (p^.next = nil)) then
                p := nil
              else
                p := win7_cur_req^.next;
              if cmd = win7_op_read then
                drive^.stats.reads := drive^.stats.reads + n
              else
                drive^.stats.writes := drive^.stats.writes + n;
            end;
          end;
        end;
      until (p = nil) or (status.all <> status_$ok);
    end;

    otherwise begin
      status.all := status_$unknown_error_status_from_drive;
    end;
  end;

  if status.all = status_$ok then begin
    result := true;
    cb^.cur^.info^.in_mbox := false;
    goto 90;
  end;

  { the failure: the chain's statuses, the block and its window back }
50:
  token := ml_$spin_lock(cb^.spin);
  cb^.procs[proc1_$current][vol.dev_unit].flags :=
    cb^.procs[proc1_$current][vol.dev_unit].flags + [15];
  disk_bptbl[proc1_$current].io_pending := false;
  result := true;
  if cb^.procs[proc1_$current][vol.dev_unit].count = 0 then
    ec_$advance(disk_bptbl[proc1_$current].io_ec);
  repeat
    p^.status := status;
    p := p^.next;
  until p = nil;
  if cb^.cur <> nil then begin
    info := cb^.cur^.info;
    if cb^.cur^.info^.buf <> 0 then
      if (cb^.cur^.op = win7_op_format) or (cb^.cur^.op = win7_op_read) or
         (cb^.cur^.op = win7_op_write) or
         (cb^.cur^.op = win7_op_format_track) then
        iomap_$unmap(3, info^.buf, 16);
    if cb^.cur = cb^.busy then
      win7_$move_iopb(cb^.busy, cb^.free)
    else
      win7_$move_iopb(cb^.cur, cb^.free);
    if info^.in_mbox then begin
      if cb^.mbox_index = 0 then
        cb^.mbox^.out[61].status := 0
      else
        cb^.mbox^.out[cb^.mbox_index - 1].status := 0;
      info^.in_mbox := false;
    end;
    free_buffer(cb^.cur^.info^.buf);
  end
  else
    free_buffer(buf);
  ml_$spin_unlock(cb^.spin, token);

90:
  ml_$unlock(cb^.lock);
end;
