{ SEEK - position the drive for a request: select its head, then seek its
  cylinder.

  Image addresses:
    sau2  0x00E19576  SEEK
    sau4  0x0F819A74  seek (module-local)
    sau5  0x00E19AE6  SEEK
    sau6  0x78019F1A  SEEK

  - The ANSI form, up to two tries: the head selected and checked, the
    cylinder sought; a caller that does not wait gets -1 at once, one
    that waits waits 8 ticks and checks.
  - Not ready, an unknown status, an equipment check or a timeout
    re-initialize the drive.
  - The descriptor-list form positions a drive for RETRY_DATA_CHECK, up
    to two seek commands.
  - Two timeouts return 0 without recording the cylinder.
  - The ring/disk form (module-local) takes the cylinder alone: a drive
    on its cylinder already is left there; one not ready or at fault is
    brought up (DISK_INIT) when the caller waits, else the seek fails;
    the seek is started with the board's interrupt and, for a caller
    that waits, checked after the interrupt or 40 ticks.

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
%elseif win_ring_disk_ctlr %then

function seek(ctlr: pinteger; drive: pinteger; cyl: pinteger;
              wait: boolean): integer32;
  internal;
label
  10, 20, 30;
var
  regs: win_$regs_ptr_t;
  sel: win_$byte_t;
  wait_val: integer32;
  which: integer;
  tries: integer;
  scratch: pinteger;
  geometry: win_$geometry_t;
begin
  regs := win_units[ctlr].regs;

  for tries := 1 to 2 do begin
    if win_smd_interface in win_units[ctlr].unit_bits then begin
      { the SMD interface: on the drive's cylinder already }
      if (drive = win_cur_drive) and then (cyl = win_cyls[win_cur_drive]) then
        goto 30;

      { select the drive; a drive not ready is brought up first }
      sel := lshft(drive, 4) & 16#70;
      regs^.select := sel;
      regs^.cmd := 0;
      regs^.cmd := 1;
      if (regs^.cmd & 16#0F) <> 3 then begin
        if (regs^.cmd & 16#0C) <> 0 then
          win_$cnt.equip_checks := win_$cnt.equip_checks + 1
        else if not (0 in regs^.status) then
          win_$cnt.not_ready := win_$cnt.not_ready + 1;
        if not wait then
          goto 20;
        discard(disk_init(ctlr, drive, win_total_blocks, scratch, scratch,
                          geometry, scratch));
      end;
      regs^.cmd := 16#11;
      if ((regs^.cmd & 7) & 6) <> 6 then begin
        win_$cnt.equip_checks := win_$cnt.equip_checks + 1;
        if not wait then
          goto 20;
        discard(disk_init(ctlr, drive, win_total_blocks, scratch, scratch,
                          geometry, scratch));
      end;

      { the cylinder, through the head register, and the seek }
      win_cur_drive := drive;
      regs^.cyl_hi := rshft(cyl, 8) & 3;
      regs^.cyl_lo := cyl & 16#FF;
      regs^.select := sel ! 16#80;
      regs^.head := rshft(cyl, 8) & 3;
      regs^.select := sel;
      regs^.head := cyl & 16#FF;
      wait_val := win_unit_ec[ctlr].value + 1;
      win_flag := not wait;
      regs^.control := win_ctl_int;
      regs^.cmd := 9;
    end
    else begin
      { the PRIAM interface: select the drive; a drive not ready, or at
        fault, is brought up first }
      regs^.select := 255 - lshft(16, drive);
      if (regs^.cmd & 16#35) <> 1 then begin
        if (regs^.cmd & 16#24) <> 0 then
          win_$cnt.equip_checks := win_$cnt.equip_checks + 1
        else if not (win_st_ready in regs^.status) then
          win_$cnt.not_ready := win_$cnt.not_ready + 1
        else if win_st_busy in regs^.status then
          { empty };
        if not wait then
          goto 20;
        discard(disk_init(ctlr, drive, win_total_blocks, scratch, scratch,
                          geometry, scratch));
      end;

      { the cylinder: there already when the registers read it back }
      regs^.cyl_hi := rshft(cyl, 8);
      regs^.cyl_lo := cyl & 16#FF;
      if (regs^.cyl_hi = rshft(cyl, 8)) and then
         (regs^.cyl_lo = cyl & 16#FF) then
        goto 30;
      wait_val := win_unit_ec[ctlr].value + 1;
      win_flag := not wait;
      regs^.control := win_ctl_int;
      regs^.cmd := win_cmd_seek;
    end;

    { under way, WIN_$INT finishes it }
    if not wait then begin
      seek := -1;
      return;
    end;

    { the interrupt, or 40 ticks }
    which := ec_$wait(addr(win_unit_ec[ctlr]),
                      ec_$eventcount_ptr_t(addr(time_$clockh)),
                      addr(ec_$nil_ec), wait_val, time_$clockh + 40, 0);
    if win_smd_interface in win_units[ctlr].unit_bits then begin
      if (which = 0) and then ((regs^.cmd & 16#0F) = 3) then begin
        win_cyls[drive] := cyl;
        goto 10;
      end;
    end
    else if (which = 0) and then ((regs^.cmd & 16#B7) = 3) then
      goto 10;
  end;

  { two failures, or a drive not ready without waiting }
20:
  win_$cnt.seek_errors := win_$cnt.seek_errors + 1;
  seek := status_$disk_seek_error;
  return;

30:
  win_flag := false;
10:
  seek := status_$ok;
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
