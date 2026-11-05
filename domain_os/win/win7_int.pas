{ WIN7_$INT - the controller's interrupt routine.

  Image addresses:
    sau7  0x3C41C52E  win7_$move_iopb (nested)
    sau7  0x3C41C5C0  save_params (nested)
    sau7  0x3C41C634  free_buffer (nested)
    sau7  0x3C41C650  WIN7_$INT

  - A completion names its incoming mailbox; the block's address there
    leads back to the block.  A block done goes back to the free list, a
    failed one (completion codes 2, 3, 16, 17 and 18) to the failed list
    with its code and the process's record marked.  The drive
    parameters' block, done or failed, records the parameters and wakes
    WIN7_$DINIT.
  - A transfer's or a format's window is unmapped and freed; the
    process's count of blocks taken down, and at its chain's last its
    eventcount advanced, the error eventcount after a failure.
  - A free outgoing mailbox advances win7_mbox_ec.
  - The interrupt is acknowledged; the result is true.

  Status stored: none.
}

function win7_$int(in dcte: win_$dcte_t): boolean;
var
  cb: win7_$ctlr_ptr_t;
  mbox: win7_$mbox_ptr_t;
  regs: win7_$regs_ptr_t;
  idx: integer32;
  p: win7_$iopb_ptr_t;
  local: win7_$iopb_ptr_t;
  info: win7_$info_ptr_t;
  op: integer;
  r: disk_$io_req_ptr_t;

  { win7_$move_iopb - move a command block from one list to the front of
    another (the module-level routine's body). }
  procedure win7_$move_iopb(in out from: win7_$iopb_ptr_t;
                      in out onto: win7_$iopb_ptr_t);
  var
    p: win7_$iopb_ptr_t;
    n: win7_$iopb_ptr_t;
  begin
    p := from;
    if p^.info^.prev = nil then begin
      n := p^.info^.next;
      p^.info^.next := onto;
      if onto <> nil then
        onto^.info^.prev := p;
      onto := p;
      from := n;
      if from <> nil then
        from^.info^.prev := nil;
    end
    else begin
      n := p^.info^.next;
      p^.info^.prev^.info^.next := n;
      if n <> nil then
        n^.info^.prev := p^.info^.prev;
      p^.info^.next := onto;
      p^.info^.prev := nil;
      if onto <> nil then
        onto^.info^.prev := p;
      onto := p;
    end;
  end;

  { save_params - record the parameters a drive reported in its record. }
  procedure save_params(cnum: pinteger; in iopb: win7_$iopb_t);
  var
    drive: win7_$drive_ptr_t;
  begin
    drive := addr(win7_ctlrs[cnum]^.drives[iopb.info^.unit]);
    drive^.heads := iopb.heads;
    drive^.sectors := iopb.sectors;
    drive^.cyls := iopb.cyls - 1;
    drive^.precomp := iopb.precomp;
    drive^.valid := true;
  end;

  { free_buffer - give a window back to the pool. }
  procedure free_buffer(buf: integer32);
  begin
    win7_buf_index := win7_buf_index - 1;
    win7_bufs[win7_buf_index] := buf;
  end;

begin
  cb := win7_ctlrs[dcte.cnum];
  mbox := cb^.mbox;
  regs := cb^.regs;
  if (regs^.int & win7_int_mask) = win7_int_mailbox then begin
    { the block the incoming mailbox names }
    idx := regs^.int & win7_int_mbox_number;
    if (idx > 62) or (idx < 0) then
      crash_system(status_$disk_controller_error);
    p := win7_$iopb_ptr_t((mbox^.inb[idx].w & 16#FFFFFF) - cb^.iopb_pa +
                          win7_iopb_base[dcte.cnum]);
    if mbox^.inb[idx].status = win7_done then begin
      if p^.info^.prev = nil then
        win7_$move_iopb(cb^.busy, cb^.free)
      else begin
        local := p;
        win7_$move_iopb(local, cb^.free);
      end;
      p := cb^.free;
      if p^.op = win7_op_drive_params then begin
        save_params(dcte.cnum, p^);
        ec_$advance_without_dispatch(win7_init_ec);
        regs^.int := 1;
        win7_params_ok := true;
        win7_$int := true;
        return;
      end;
    end
    else if (mbox^.inb[idx].status = win7_failed_17) or
            (mbox^.inb[idx].status = win7_failed_18) or
            (mbox^.inb[idx].status = win7_failed_16) or
            (mbox^.inb[idx].status = win7_failed_2) or
            (mbox^.inb[idx].status = win7_failed_3) then begin
      if p^.op = win7_op_drive_params then begin
        save_params(dcte.cnum, p^);
        ec_$advance_without_dispatch(win7_init_ec);
        if p^.info^.prev = nil then
          win7_$move_iopb(cb^.busy, cb^.free)
        else begin
          local := p;
          win7_$move_iopb(local, cb^.free);
        end;
        regs^.int := 1;
        win7_params_ok := false;
        win7_$int := true;
        return;
      end;
      if p^.info^.prev = nil then
        win7_$move_iopb(cb^.busy, cb^.done)
      else begin
        local := p;
        win7_$move_iopb(local, cb^.done);
      end;
      p := cb^.done;
      p^.info^.status := mbox^.inb[idx].status;
      cb^.procs[p^.info^.req^.owner_op.owner][p^.info^.unit].flags :=
        cb^.procs[p^.info^.req^.owner_op.owner][p^.info^.unit].flags + [14];
    end;

    { the window, and the process's count of blocks }
    info := p^.info;
    op := p^.op;
    if (op = win7_op_format) or (op = win7_op_read) or
       (op = win7_op_write) or (p^.op = win7_op_format_track) then
      iomap_$unmap(3, info^.buf, 16);
    free_buffer(info^.buf);
    info^.buf := 0;
    info := p^.info;
    r := info^.req;
    if cb^.procs[r^.owner_op.owner][info^.unit].count > 0 then
      cb^.procs[r^.owner_op.owner][info^.unit].count :=
        cb^.procs[r^.owner_op.owner][info^.unit].count - 1
    else
      crash_system(status_$disk_driver_logic_error);
    if (cb^.procs[r^.owner_op.owner][info^.unit].count = 0) and
       (15 in cb^.procs[r^.owner_op.owner][info^.unit].flags) then
      if 14 in cb^.procs[r^.owner_op.owner][info^.unit].flags then begin
        ec_$advance_without_dispatch(disk_bptbl[r^.owner_op.owner].err_ec);
        disk_bptbl[r^.owner_op.owner].io_pending := false;
        cb^.procs[r^.owner_op.owner][info^.unit].flags :=
          cb^.procs[r^.owner_op.owner][info^.unit].flags - [14];
      end
      else
        ec_$advance_without_dispatch(disk_bptbl[r^.owner_op.owner].io_ec);
  end
  else if (regs^.int & win7_int_mask) = win7_int_free then
    ec_$advance_without_dispatch(win7_mbox_ec)
  else
    crash_system(status_$disk_unrecognized_interrupt);
  regs^.int := 1;
  win7_$int := true;
end;
