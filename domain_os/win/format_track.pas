{ win_$format_track - format the track of a format request.

  Image addresses:
    sau2  0x00E196AA  win_$format_track (module-local)
    sau4  0x0F819E9A  win_$format_track (module-local)
    sau5  0x00E19A6C  win_$format_track
    sau6  0x78019EA0  win_$format_track
    sau7  0x3C41CD0C  win_$format_track
    sau8  0x03C1A360  win_$format_track

  - Up to five tries: the ANSI form seeks to the cylinder, starts the
    format and checks the drive after the unit's eventcount or 40 ticks;
    the descriptor-list form gives the format command (win_$command);
    the AT bus form sends the format command with the interleave (1 for
    a volume whose unit word is 1536 or more) and checks the drive after
    the controller's eventcount or 80 ticks.
  - The ring/disk form seeks (on the SMD interface unless the drive is
    on the cylinder), starts the format with the interrupt and checks
    the controller and the drive after the interrupt or 40 ticks; a
    fault on the SMD interface re-initializes the drive (DISK_INIT).
  - After five failures the requesting process's pending byte is
    cleared.

  Status stored (in the request):
    the last try's status: five tries failed
}

%if win_descriptor_ctlr %then
procedure win_$format_track(in vol: disk_$volume_t;
                            var req: disk_$io_req_t);
  internal;
var
  ctlr: pinteger;
  regs: win_$regs_ptr_t;
  status: integer32;
  tries: integer;
begin
  ctlr := 0;
  regs := win_units[0].regs;
  regs^.desc[1].cyl := req.daddr.cyl;
  regs^.desc[1].head := req.daddr.head;
  regs^.desc[1].drive := vol.dev_unit;
  regs^.count := 1;
  win_cur_req := nil;

  for tries := 1 to 5 do begin
    status := win_$command(ctlr, win_cmd_format);
    if status = status_$ok then
      exit;
  end;

  { five failures }
  if status <> status_$ok then begin
    disk_bptbl[req.owner_op.owner].io_pending := false;
    req.status.all := status;
  end;
end;
%elseif win_atbus_ctlr %then
procedure win_$format_track(in vol: disk_$volume_t;
                            var req: disk_$io_req_t);
  internal;
var
  regs: win_$regs_ptr_t;
  tries: integer;
  wait_val: integer32;
  status: integer32;
begin
  win_cmd.unit := vol.dev_unit;
  if vol.unit_id >= 1536 then
    win_cmd.interleave_hi := 1
  else
    win_cmd.interleave_hi := 0;
  win_cmd.interleave_lo := 0;
  regs := win_units[0].regs;

  for tries := 1 to 5 do begin
    wait_val := win_unit_ec[vol.dev_info^.controller].value + 1;
    regs^.ctl := win_ctl_int_on;
    status := win_$send_command(win_cmd_format_track, req.daddr.cyl,
                                req.daddr.head, 0);
    if status <> status_$ok then begin
      regs^.ctl := win_ctl_int_off;
      exit;
    end;
    discard(ec_$wait(addr(win_unit_ec[vol.dev_info^.controller]),
                     ec_$eventcount_ptr_t(addr(time_$clockh)),
                     addr(ec_$nil_ec), wait_val, time_$clockh + 80, 0));
    status := win_$check_status(vol.dev_unit);
    if status = status_$ok then
      exit;
  end;

  if status <> status_$ok then begin
    req.status.all := status;
    disk_bptbl[req.owner_op.owner].io_pending := false;
  end;
end;
%elseif win_ring_disk_ctlr %then

procedure win_$format_track(in vol: disk_$volume_t;
                            var req: disk_$io_req_t);
  internal;
var
  unit: pinteger;
  cyl: pinteger;
  head: pinteger;
  regs: win_$regs_ptr_t;
  attempts: integer;
  status: integer32;
  sel: pinteger;
  wait_val: integer32;
  scratch: pinteger;
  geometry: win_$geometry_t;
begin
  unit := 0;
  win_cur_req := nil;
  cyl := req.daddr.cyl;
  head := req.daddr.head;
  regs := win_units[0].regs;

  for attempts := 1 to 5 do
    if win_smd_interface in win_units[0].unit_bits then begin
      { the SMD interface: on the cylinder, or a seek }
      status := status_$ok;
      if (win_cur_drive <> vol.dev_unit) or else
         (win_cyls[win_cur_drive] <> cyl) then
        status := seek(unit, vol.dev_unit, cyl, true);
      if status = status_$ok then begin
        { the drive and head, the cylinder's high bits, sector 0 }
        sel := (lshft(vol.dev_unit, 4) & 16#70) ! (15 - (head & 15));
        regs^.select := sel ! 16#80;
        regs^.head := 0;
        regs^.select := sel;
        regs^.head := head;
        regs^.cmd := 5;
        regs^.sector := 0;
        regs^.cyl_hi := (head & 16#F0) ! (rshft(cyl, 8) & 3);
        regs^.select := sel ! 16#80;
        regs^.head := 0;
        regs^.select := sel;
        regs^.head := 0;

        { format, and the interrupt or 40 ticks }
        wait_val := win_unit_ec[0].value + 1;
        regs^.cmd := 3;
        regs^.control := win_ctl_format;
        discard(ec_$wait(addr(win_unit_ec[0]),
                         ec_$eventcount_ptr_t(addr(time_$clockh)),
                         addr(ec_$nil_ec), wait_val, time_$clockh + 40, 0));
        regs^.cmd := 1;
        if (regs^.ctlr_status = 0) and then not (3 in regs^.status) then
          return;
        if 3 in regs^.status then
          status := disk_init(unit, vol.dev_unit, win_total_blocks,
                              scratch, scratch, geometry, scratch)
        else if win_cs_timeout in regs^.ctlr_bits then
          status := status_$drive_timed_out;
      end;
    end
    else begin
      { the PRIAM interface: a seek }
      status := seek(unit, vol.dev_unit, cyl, true);
      if status = status_$ok then begin
        { the drive and head, sector 0; format, and the interrupt or 40
          ticks }
        regs^.select := 255 - (lshft(16, vol.dev_unit) + head);
        regs^.sector := 0;
        wait_val := win_unit_ec[0].value + 1;
        regs^.control := win_ctl_format;
        discard(ec_$wait(addr(win_unit_ec[0]),
                         ec_$eventcount_ptr_t(addr(time_$clockh)),
                         addr(ec_$nil_ec), wait_val, time_$clockh + 40, 0));
        if (regs^.ctlr_status = 0) and then
           not (win_st_drive_fault in regs^.status) then
          return;
        if win_st_drive_fault in regs^.status then
          status := status_$disk_equipment_check
        else if win_cs_timeout in regs^.ctlr_bits then
          status := status_$drive_timed_out;
      end;
    end;

  { five failures }
  if status <> status_$ok then begin
    disk_bptbl[req.owner_op.owner].io_pending := false;
    req.status.all := status;
  end;
end;
%else

{ TODO(pascal) eight frame bytes in win_$format_track

  In the SAU2 frame the reserved slot, wait_val, status, unit, regs and
  attempts take 0x16 bytes, rounded to 0x18, of 0x20.  The stand-in
  unused_20 holds the other 8; what they were is not known. }

procedure win_$format_track(in vol: disk_$volume_t;
                            var req: disk_$io_req_t);
  internal;
var
  wait_val: integer32;
  status: integer32;
  unit: pinteger;
  regs: win_$regs_ptr_t;
  attempts: integer;
  unused_20: array[1..2] of integer32;    { never addressed: the TODO }
begin
  unit := 0;
  win_cur_req := nil;
  regs := win_units[0].regs;

  for attempts := 1 to 5 do begin
    status := seek(unit, vol.dev_unit, req, true);
    if status = status_$ok then begin
      { format }
      regs^.sector := 0;
      wait_val := win_unit_ec[0].value + 1;
      regs^.mode := 9;
      regs^.go := 3;

      { the interrupt, or 40 ticks }
      discard(ec_$wait(addr(win_unit_ec[0]),
                       ec_$eventcount_ptr_t(addr(time_$clockh)),
                       addr(ec_$nil_ec), wait_val, time_$clockh + 40, 0));

      status := win_$check_disk_status(unit);
      if status = status_$ok then
        return;
    end;
  end;

  { five failures }
  if status <> status_$ok then begin
    disk_bptbl[req.owner_op.owner].io_pending := false;
    req.status.all := status;
  end;
end;
%endif
