{ WIN6_$DO_IO - the I/O entry of the second board's driver.

  Image addresses:
    sau6  0x7801B0F8  WIN6_$DO_IO

  - One command block per request: a format of the request's track, a
    format of the drive (at its last cylinder, eight cylinders lower
    after half the retries), or the chain of reads or writes (a write
    chain of more than one sorted first).  The blocks are chained and
    started, or queued (win6_$send_iopb).
  - Without free blocks the request is the process's failed request and
    its error eventcount is advanced: WIN6_$ERROR_QUE starts it again.
  - Another operation, or a chain that does not end with the blocks:
    CRASH_SYSTEM with the driver logic error.

  Status stored: none.
}

procedure win6_$do_io(in vol: disk_$volume_t; var req: disk_$io_req_t;
                      in param_3: univ integer32; out result: boolean);
var
  unit: pinteger;
  owner: integer;
  p: disk_$io_req_ptr_t;
  opts: integer;
  wop: integer;
  n: integer;
  local_req: disk_$io_req_ptr_t;
  chain: disk_$io_req_ptr_t;
  busy: boolean;
  first: integer;
  last: integer;
  idx: integer;
  i: integer;
  iopb: win6_$iopb_ptr_t;
begin
  result := true;
  unit := vol.dev_unit;
  owner := req.owner_op.owner;
  p := addr(req);
  if p^.owner_op.chksum then
    opts := win6_opt_chksum
  else
    opts := 0;

  { the operation and the number of blocks }
  case p^.owner_op.op of
    disk_$req_op_format_track: begin
      wop := win6_op_format_track;
      n := 1;
    end;
    disk_$req_op_format: begin
      wop := win6_op_format;
      n := 1;
      if p^.flags > win6_$retries div 2 then
        p^.daddr.cyl := win6_drives[unit].geom.cyls - 8
      else
        p^.daddr.cyl := win6_drives[unit].geom.cyls;
      p^.daddr.sector := 0;
    end;
    otherwise begin
      n := 0;
      repeat
        p := p^.next;
        n := n + 1;
      until p = nil;
      p := addr(req);
      case p^.owner_op.op of
        disk_$req_op_read: begin
          wop := win6_op_read;
          win_$cnt.xfer_other := win_$cnt.xfer_other + n;
        end;
        disk_$req_op_write: begin
          wop := win6_op_write;
          win_$cnt.xfer_op2 := win_$cnt.xfer_op2 + n;
          if n > 1 then begin
            local_req := p;
            disk_$sort(vol, local_req);
            p := local_req;
          end;
        end;
        otherwise begin
          crash_system(status_$disk_driver_logic_error);
        end;
      end;
    end;
  end;

  { the blocks, or the failed request without them }
  chain := p;
  busy := win6_$get_iopbs(n, first, last) <> 0;
  idx := first;
  if busy then begin
    win6_drives[unit].failed[owner] := chain;
    advance(disk_bptbl[owner].err_ec);
    return;
  end;

  { one block per request, in the chain's order }
  i := idx;
  repeat
    iopb := addr(win6_page^.iopbs[i]);
    p^.reserved_18 := iopb;
    with iopb^ do begin
      req := p;
      status := -1;
      opu.op := wop;
      opu.unused_72 := 0;
      opu.unit := unit;
      state := opts;
      f_0a.w := 0;
      case wop of
        win6_op_format_track: begin
          with fmt do begin
            cyl := p^.daddr.cyl;
            head := p^.daddr.head;
            zero_13 := 0;
            cyl_2 := p^.daddr.cyl;
            head_2 := p^.daddr.head;
            code := win6_format_code;
            zero_18 := 0;
          end;
        end;
        win6_op_format: begin
          daddr := p^.daddr;
          phys := 0;
          buf := p^.ppn * 1024;
        end;
        otherwise begin
          daddr := p^.daddr;
          phys := p^.phys;
          buf := p^.ppn * 1024;
        end;
      end;
      l_1c := 0;
      if link = win6_end_of_chain then
        i := win6_end_of_chain
      else
        i := link div win6_iopb_size;
    end;
    p := p^.next;
  until (p = nil) or (i = win6_end_of_chain);
  if (p <> nil) and then (i <> win6_end_of_chain) then begin
    crash_system(status_$disk_driver_logic_error);
    return;
  end;

  { the chain started }
  win6_page^.iopbs[idx].state := win6_page^.iopbs[idx].state ! win6_state_used;
  win6_drives[unit].failed[owner] := nil;
  win6_$send_iopb(idx);
end;
