{ DISK_INIT - bring a drive up and find its geometry.

  Image addresses:
    sau2  0x00E19986  DISK_INIT
    sau4  0x0F81A29C  DISK_INIT

  - Up to ten tries, with no current request: the drive's
    initialization, the general status, a spin-up when stopped (waiting
    120 ticks) and write enable.
  - Attribute 2 gives the drive id (16#100 plus its low nibble); a caller
    with no geometry gets the three known drives'.
  - An unknown drive's multiply overwrites total_blocks.
  - The ring/disk form: up to ten tries to select the drive and bring
    it up, on the SMD interface to cylinder 0 (the drive id 16#200 plus
    its type), on the PRIAM interface by a fault reset, a sequence up or
    a restore (the drive id its type, plus 16#100 for types 4 and 5),
    each try waiting 40 ticks; with no current request (the caller's is
    put back).  The geometry: the SMD drive's own record, the PRIAM
    drive types' table.

  Returns:
    status_$ok: the drive came up
    status_$invalid_unit_number: a sub-unit other than 0 (the ring/disk
      form: no drive answers)
    status_$disk_equipment_check: the ring/disk form's drive did not
      come up
    an ANSI command's or win_$check_disk_status' status: a step failed
    status_$unrecognized_drive_id: an unknown drive

  Status stored: none.
}

%if win_ring_disk_ctlr %then
function disk_init(ctlr: pinteger; drive: pinteger;
                   var total_blocks: integer32;
                   var blocks_per_track: pinteger; var heads: pinteger;
                   out geometry: win_$geometry_t;
                   out drive_id: pinteger): integer32;
var
  status: integer32;
  saved_req: disk_$io_req_ptr_t;
  wait_val: integer32;
  regs: win_$regs_ptr_t;
  attempt: integer;
  sel: pinteger;
  bit: win_$byte_t;
  dtype: pinteger;
  junk: win_$byte_t;
  count: pinteger;
  len: pinteger;
  i: pinteger;
  j: pinteger;
  per_cyl: pinteger;
  cyl: pinteger;
  info: win_$smd_info_t;
begin
  status := status_$disk_equipment_check;
  saved_req := win_cur_req;
  win_cur_req := nil;

  if win_smd_interface in win_units[ctlr].unit_bits then begin
    { the SMD interface: up to ten tries to select the drive and bring it
      to cylinder 0 }
    regs := win_units[ctlr].regs;
    sel := lshft(drive, 4) & 16#70;
    for attempt := 1 to 10 do begin
      regs^.cmd := 0;
      regs^.select := sel;
      regs^.cmd := 16#11;
      if not (2 in regs^.status) then begin
        status := status_$invalid_unit_number;
        exit;
      end;
      while win_cs_busy in regs^.ctlr_bits do
        ;
      dtype := rshft(regs^.cmd & 16#78, 3);
      drive_id := dtype + 16#200;
      win_cur_drive := drive;
      wait_val := win_unit_ec[ctlr].value + 1;
      regs^.cmd := 1;

      { a fault: cleared, and an equipment check if it stays }
      if 3 in regs^.status then begin
        regs^.select := sel ! 16#80;
        regs^.head := 0;
        regs^.select := sel;
        regs^.head := 16#10;
        regs^.control := win_ctl_off;
        regs^.cmd := 3;
        regs^.cmd := 1;
        status := status_$disk_equipment_check;
        if 3 in regs^.status then begin
          status := status_$disk_equipment_check;
          exit;
        end;
      end;

      { to cylinder 0, and the interrupt or 40 ticks }
      regs^.select := sel ! 16#80;
      regs^.head := 0;
      regs^.select := sel;
      regs^.head := 16#40;
      regs^.control := win_ctl_int;
      regs^.cmd := 3;
      regs^.cmd := 1;
      discard(ec_$wait(addr(win_unit_ec[ctlr]),
                       ec_$eventcount_ptr_t(addr(time_$clockh)),
                       addr(ec_$nil_ec), wait_val, time_$clockh + 40, 0));
      if (regs^.cmd & 16#0F) = 3 then begin
        regs^.cyl_hi := 0;
        regs^.cyl_lo := 0;
        win_cyls[drive] := 0;
        status := status_$ok;
        exit;
      end;
    end;

    { the geometry, if the caller has none: the drive's information
      record, the record of the drive's own type among those it sends }
    if (status = status_$ok) and then (total_blocks <= 0) then begin
      regs^.cmd := 0;
      regs^.cmd := 16#20;
      junk := regs^.cmd;
      junk := regs^.cmd;
      len := lshft(regs^.cmd, 8) ! regs^.cmd;
      if len > 32 then
        len := 32;
      count := lshft(regs^.cmd, 8) ! regs^.cmd;
      for i := 1 to count do
        if regs^.cmd <> dtype then
          for j := 2 to len do
            junk := regs^.cmd
        else begin
          info.b[1] := dtype;
          for j := 2 to len do
            info.b[j] := regs^.cmd;
          blocks_per_track := info.spt;
          heads := info.heads;
          per_cyl := heads * blocks_per_track;
          total_blocks :=
            (info.cyls - (info.w_0a + per_cyl div 2) div per_cyl) * per_cyl;
          geometry[0] := info.w_08;
          geometry[1] := info.w_06;
        end;
    end;
  end
  else begin
    { the PRIAM interface: up to ten tries to select the drive, read its
      type and bring it up (a fault reset, a sequence up or a restore) }
    regs := win_units[ctlr].regs;
    bit := lshft(16, drive);
    for attempt := 1 to 10 do begin
      regs^.select := 255 - bit;
      if regs^.cmd = 255 then begin
        status := status_$invalid_unit_number;
        exit;
      end;
      while win_st_busy in regs^.status do
        ;
      regs^.cmd := 16#10;
      while win_st_busy in regs^.status do
        ;
      dtype := regs^.cyl_lo;
      case dtype of
        1, 6, 7: drive_id := dtype;
        4, 5: drive_id := dtype + 16#100;
      end;
      wait_val := win_unit_ec[ctlr].value + 1;
      if (regs^.cmd & 16#24) <> 0 then
        regs^.cmd := win_cmd_fault_reset
      else begin
        if not (win_st_ready in regs^.status) then begin
          regs^.control := win_ctl_int;
          regs^.cmd := win_cmd_sequence_up;
        end
        else begin
          regs^.control := win_ctl_int;
          regs^.cmd := win_cmd_restore;
        end;
        discard(ec_$wait(addr(win_unit_ec[ctlr]),
                         ec_$eventcount_ptr_t(addr(time_$clockh)),
                         addr(ec_$nil_ec), wait_val, time_$clockh + 40,
                         0));
        if (regs^.cmd & 16#BD) = 9 then begin
          status := status_$ok;
          exit;
        end;
      end;
    end;

    { the geometry, if the caller has none: the drive types' }
    if (status = status_$ok) and then (total_blocks <= 0) then begin
      case dtype of
        1: begin
          blocks_per_track := 18;
          heads := 3;
          cyl := 561;
        end;
        4: begin
          blocks_per_track := 12;
          heads := 5;
          cyl := 525;
        end;
        5: begin
          blocks_per_track := 12;
          heads := 5;
          cyl := 1049;
        end;
        6: begin
          blocks_per_track := 18;
          heads := 3;
          cyl := 1121;
        end;
        7: begin
          blocks_per_track := 18;
          heads := 7;
          cyl := 1121;
        end;
        otherwise begin
          status := status_$unrecognized_drive_id;
        end;
      end;
      total_blocks := heads * cyl * blocks_per_track;
      geometry[0] := 16#22;
      geometry[1] := 16#45E;
    end;
  end;

  win_cur_req := saved_req;
  disk_init := status;
end;
%else

{ TODO(pascal) eight frame bytes in DISK_INIT

  In the SAU2 frame status, wait_val, the 4-byte result variable (in the
  one open longword above gen: its place uncertain), attempt, drive,
  gen, cyl and attr take 0x16 bytes, rounded to 0x18; 8 more make 0x20.
  The stand-in unused_20 holds them; what they were is not known (an
  eventcount pointer and a track count longword would be 8, but the
  image keeps neither: the eventcount is reached through the scaled
  index, the product stays in a register). }

function disk_init(unit: pinteger; sub_unit: integer;
                   var total_blocks: integer32;
                   var blocks_per_track: pinteger; var heads: pinteger;
                   out geometry: win_$geometry_t;
                   out drive_id: pinteger): integer32;
var
  status: integer32;
  wait_val: integer32;
  attempt: integer;
  drive: win_$byte_t;
  gen: win_$byte_t;
  cyl: integer;
  attr: win_$byte_t;
  unused_20: array[1..2] of integer32;    { never addressed: the TODO }
begin
  { only sub-unit 0 }
  if sub_unit <> 0 then begin
    disk_init := status_$invalid_unit_number;
    return;
  end;

  win_cur_req := nil;

  for attempt := 1 to 10 do begin
    { initialize, then the general status }
    win_units[unit].regs^.param := 1;
    win_units[unit].regs^.go := 6;
    discard(wait_for_controller(unit));
    status := win_$ansi_command(unit, 16#0F, chr(0), gen);
    discard(win_$check_disk_status(unit));
    if status <> status_$ok then
      next;

    { a stopped spindle is spun up }
    if (gen & 1) <> 0 then begin
      win_units[unit].regs^.mode := 16#0A;
      wait_val := win_unit_ec[unit].value + 1;
      discard(win_$ansi_command(unit, 16#55, chr(16#80), gen));
      discard(ec_$wait(addr(win_unit_ec[unit]),
                       ec_$eventcount_ptr_t(addr(time_$clockh)),
                       addr(ec_$nil_ec), wait_val, time_$clockh + 120,
                       0));
      status := win_$check_disk_status(unit);
      if status <> status_$ok then
        next;
    end;

    { writing on }
    discard(win_$ansi_command(unit, 16#41, chr(16#80), gen));
    status := win_$check_disk_status(unit);
    if status = status_$ok then
      exit;
  end;

  if status = status_$ok then begin
    { the drive's attribute 2 }
    discard(win_$ansi_command(unit, 16#50, chr(2), attr));
    drive := attr;
    if win_$check_disk_status(unit) = status_$ok then begin
      discard(win_$ansi_command(unit, 16#10, chr(0), attr));
      drive := attr;
    end;
    status := win_$check_disk_status(unit);
    cyl := drive & 15;
    drive_id := cyl + 16#100;

    { the geometry, if the caller has none }
    if status = status_$ok then
      if total_blocks <= 0 then begin
        geometry[0] := 0;
        case cyl of
          4: begin
            blocks_per_track := 12;
            heads := 5;
            cyl := 525;
            geometry[1] := 1120;
          end;
          3: begin
            blocks_per_track := 12;
            heads := 5;
            cyl := 525;
            geometry[1] := 1181;
          end;
          5: begin
            blocks_per_track := 12;
            heads := 5;
            cyl := 1049;
            geometry[1] := 1120;
          end;
          otherwise begin
            status := status_$unrecognized_drive_id;
          end;
        end;
        total_blocks := heads * cyl * blocks_per_track;
      end;
  end;

  disk_init := status;
end;
%endif
