{ SEEK - position the drive for a request: select its head, then seek its
  cylinder.

  Image addresses:
    sau2  0x00E19576  SEEK
    sau5  0x00E19AE6  SEEK

  - The ANSI form, up to two tries: the head selected and checked, the
    cylinder sought; a caller that does not wait gets -1 at once, one
    that waits waits 8 ticks and checks.
  - Not ready, an unknown status, an equipment check or a timeout
    re-initialize the drive.
  - The descriptor-list form positions a drive for RETRY_DATA_CHECK, up
    to two seek commands.
  - Two timeouts return 0 without recording the cylinder.

  Returns:
    status_$ok: the drive is positioned
    -1: the seek is under way (no wait)
    status_$disk_seek_error: a re-initialization for a caller that does
      not wait
    wait_for_controller's, win_$check_disk_status' or win_$command's
      status: the last try failed

  Status stored: none.
}

%if win_descriptor_ctlr %then
function seek(in ctlr: pinteger; in dev_unit: pinteger;
              in cyl: pinteger): integer32;
var
  regs: win_$regs_ptr_t;
  saved_req: disk_$io_req_ptr_t;
  saved_desc: win_$desc_t;
  status: integer32;
  tries: integer;
begin
  regs := win_units[ctlr].regs;
  saved_req := win_cur_req;
  win_cur_req := nil;
  saved_desc := regs^.desc[1];
  regs^.desc[1].drive := dev_unit;
  regs^.desc[1].cyl := cyl;
  regs^.count := 1;

  for tries := 1 to 2 do begin
    status := win_$command(ctlr, win_cmd_seek);
    if status = status_$ok then
      exit;
  end;

  regs^.desc[1] := saved_desc;
  win_cur_req := saved_req;
  seek := status;
end;
%else

{ TODO(pascal) eight frame bytes in SEEK

  In the SAU2 frame status, wait_val, regs, head, cyl and tries take
  0x12 bytes, the 4-byte result variable 0x18 with its alignment; the
  image keeps the scaled unit index in an expression's temporary below
  the result ("Frame size" item 4), a slot dpc does not allocate.  The 8
  bytes between are not explained; the stand-in unused_20 holds them. }

function seek(unit: pinteger; dev_unit: pinteger; in req: disk_$io_req_t;
              wait: boolean): integer32;
label
  10, 20, 30;
var
  status: integer32;
  wait_val: integer32;
  regs: win_$regs_ptr_t;
  head: pinteger;
  cyl: pinteger;
  tries: integer;
  unused_20: array[1..2] of integer32;    { never addressed: the TODO }
begin
  status := status_$ok;
  cyl := req.daddr.cyl;
  head := req.daddr.head;
  regs := win_units[unit].regs;

  for tries := 1 to 2 do begin
    { the head }
    if head <> win_cur_head then begin
      regs^.head := head;
      regs^.go := 8;
      status := wait_for_controller(unit);
      if status <> status_$ok then
        goto 10;
      status := win_$check_disk_status(unit);
      if status <> status_$ok then
        goto 10;
      win_cur_head := head;
    end;

    { the cylinder }
    if cyl = win_cur_cyl then
      goto 30;
    regs^.cylinder := cyl;
    wait_val := win_unit_ec[unit].value + 1;
    win_flag := not wait;
    regs^.mode := 16#0A;
    regs^.go := 4;

    { under way, WIN_$INT finishes it }
    if not wait then begin
      seek := -1;
      return;
    end;

    { the interrupt, or 8 ticks }
    if ec_$wait(addr(win_unit_ec[unit]),
                ec_$eventcount_ptr_t(addr(time_$clockh)),
                addr(ec_$nil_ec), wait_val, time_$clockh + 8, 0) <> 0 then
      goto 20;
    status := win_$check_disk_status(unit);
    if status = status_$ok then
      goto 30;

10: if (status = status_$disk_not_ready) or else
       (status = status_$unknown_error_status_from_drive) or else
       (status = status_$disk_equipment_check) then
      goto 20;
    next;

30: win_cur_cyl := cyl;
    exit;

20: if wait then
      discard(win_$reinit_drive(unit, dev_unit))
    else begin
      status := status_$disk_seek_error;
      exit;
    end;
  end;

  seek := status;
end;
%endif
