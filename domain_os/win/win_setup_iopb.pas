{ WIN_SETUP_IOPB - take a free command block and fill it in for an
  operation.

  Image addresses:
    sau7  0x3C41B3B4  WIN_SETUP_IOPB

  - With no free block it waits up to 20 times 15 ticks for one.  The
    block moves to the busy list under the controller's spin lock and
    becomes its block being set up (cur).
  - A read or a write maps the request's pages at iova and gives the
    controller, for each request of the chain, the bus address of its
    block header, mapped through a free entry of the window pool's 16
    or one that maps its page already.
  - A format track gives the track's sector table (win7_sg, skewed by
    the request's head) through iova; a format the request's page; the
    drive parameters' block only its drive.

  Status stored:
    status_$ok: the block is set up
    status_$disk_driver_logic_error: no free block, or no I/O map entry
      for a header
    IOMAP_$MAP's or MMU_$VTOP's status: mapping failed
}

procedure win_setup_iopb(in op: integer; in iova: integer32;
                         in unit: integer; in out ctlr: win7_$ctlr_t;
                         in drive: win7_$drive_t; in count: integer;
                         in req: disk_$io_req_ptr_t;
                         in param_8: univ integer32;
                         out status: status_$t);
var
  i: integer;
  token: pinteger;
  p: win7_$iopb_ptr_t;
  tmp: win7_$bytes_t;
  r: disk_$io_req_ptr_t;
  page: integer32;
  a: integer32;
  k: integer;
  m: integer;
  offset: integer;
  npages: integer;
  vas: array[1..2] of integer32;
begin
  status.all := status_$ok;
  i := 0;
  ctlr.cur := nil;
  if ctlr.free = nil then
    repeat
      time_$wait(time_$relative, win7_iopb_wait, status);
      i := i + 1;
    until (ctlr.free <> nil) or (i = 20);
  if (i = 20) and (ctlr.free = nil) then begin
    status.all := status_$disk_driver_logic_error;
    return;
  end;

  { the block, from the free list to the busy list }
  token := ml_$spin_lock(ctlr.spin);
  win7_$move_iopb(ctlr.free, ctlr.busy);
  p := ctlr.busy;
  ml_$spin_unlock(ctlr.spin, token);
  ctlr.cur := p;

  p^.op := op;
  p^.b_02 := 0;
  p^.b_01 := 0;
  p^.stat := 0;
  p^.error := 0;
  p^.done := 0;
  p^.info^.unit := unit;
  p^.info^.count := count;
  p^.info^.req := req;
  p^.info^.in_mbox := false;
  p^.info^.owner := proc1_$current;

  case op of
    win7_op_write, win7_op_read: begin
      p^.b_05 := 0;
      p^.count := p^.info^.count;
      p^.sector := p^.info^.req^.daddr.sector;
      p^.drive_head := lshft(unit, 4) ! 16#80 ! p^.info^.req^.daddr.head;
      tmp.l := p^.info^.req^.daddr.cyl;
      p^.cyl_lo := tmp.b3;
      p^.cyl_hi := tmp.b2;
      iomap_$map(3, iova, win7_ppns, vas, p^.info^.count, 0, status);
      p^.info^.buf := iova;
      if status.all <> status_$ok then
        return;
      tmp.l := iova;
      p^.addr[2] := tmp.b3;
      p^.addr[1] := tmp.b2;
      p^.addr[0] := tmp.b1;

      { each request's header, through the window pool's entries }
      r := p^.info^.req;
      page := rshft(win7_window_base, 10);
      a := 0;
      for k := 1 to p^.info^.count do begin
        for m := 0 to 15 do begin
          if iomap[page + m] = 0 then begin
            a := win7_window_base + m * 1024;
            iomap_$map(3, a, win7_pages[k], vas, 1, 0, status);
            if status.all <> status_$ok then
              return;
            exit;
          end
          else if iomap[page + m] = win7_pages[k] then begin
            a := win7_window_base + m * 1024;
            exit;
          end;
        end;
        if a = 0 then begin
          status.all := status_$disk_driver_logic_error;
          return;
        end;
        tmp.l := a + (integer32(addr(r^.header)) & 1023);
        p^.addr[3 * k + 2] := tmp.b3;
        p^.addr[3 * k + 1] := tmp.b2;
        p^.addr[3 * k] := tmp.b1;
        r := r^.next;
      end;
      p^.info^.length := 3 * p^.info^.count + 15;
    end;

    win7_op_format_track: begin
      p^.done := 0;
      p^.b_05 := 0;
      p^.count := drive.sectors;
      p^.sector := 0;
      tmp.l := p^.info^.req^.daddr.cyl;
      p^.cyl_lo := tmp.b3;
      p^.cyl_hi := tmp.b2;
      p^.drive_head := lshft(unit, 4) ! 16#80 ! p^.info^.req^.daddr.head;

      { the sector table, starting at the request's head }
      r := p^.info^.req;
      for k := r^.daddr.head to p^.count - 1 do begin
        win7_sg[k].flag := 0;
        win7_sg[k].sector := k - r^.daddr.head;
      end;
      if r^.daddr.head <> 0 then
        for k := 0 to r^.daddr.head - 1 do begin
          win7_sg[k].flag := 0;
          win7_sg[k].sector := p^.count - r^.daddr.head + k;
        end;
      vas[1] := integer32(addr(win7_sg));
      offset := vas[1] & 1023;
      npages := 1;
      for k := 1 to 1 do begin
        win7_ppns[k] := mmu_$vtop(vas[k], status);
        if status.all <> status_$ok then
          return;
        vas[k + 1] := vas[k] + 1024;
      end;
      iomap_$map(3, iova, win7_ppns, vas, npages, 0, status);
      p^.info^.buf := iova;
      if status.all <> status_$ok then
        return;
      tmp.l := offset ! iova;
      p^.addr[2] := tmp.b3;
      p^.addr[1] := tmp.b2;
      p^.addr[0] := tmp.b1;
      p^.info^.length := 15;
    end;

    win7_op_format: begin
      p^.b_05 := 0;
      p^.count := 0;
      p^.sector := 0;
      p^.cyl_lo := 0;
      p^.cyl_hi := 0;
      p^.drive_head := lshft(unit, 4) ! 16#80;
      p^.done := 0;
      win7_ppns[1] := req^.ppn;
      iomap_$map(3, iova, win7_ppns, vas, p^.info^.count, 0, status);
      p^.info^.buf := iova;
      if status.all <> status_$ok then
        return;
      tmp.l := iova;
      p^.addr[2] := tmp.b3;
      p^.addr[1] := tmp.b2;
      p^.addr[0] := tmp.b1;
      p^.info^.length := 15;
    end;

    win7_op_drive_params: begin
      p^.drive_head := lshft(unit, 4) ! 16#80;
      p^.w_0b := 0;
      p^.cyls := 0;
      p^.w_0f := 0;
      p^.b_11 := 0;
      p^.heads := 0;
      p^.w_13 := 0;
      p^.precomp := 0;
      p^.b_17 := 0;
      p^.sectors := 0;
      p^.w_19 := 0;
      p^.b_1b := 0;
      p^.b_1c := 0;
      p^.b_1d := 0;
      p^.b_1e := 0;
      p^.b_27 := 0;
      p^.b_28 := 0;
      p^.b_29 := 0;
      p^.b_2a := 0;
      p^.w_2b := 0;
      p^.b_05 := 0;
      p^.count := 0;
      p^.sector := 0;
      p^.cyl_lo := 0;
      p^.cyl_hi := 0;
      for k := 0 to 7 do
        p^.bytes[16#1F + k] := 0;
      p^.b_2d := 0;
      p^.info^.length := 46;
    end;
  end;
end;
