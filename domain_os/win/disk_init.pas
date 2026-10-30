{ DISK_INIT - bring a drive up and find its geometry.

  Image addresses:
    sau2  0x00E19986  DISK_INIT

  - Up to ten tries, with no current request: the drive's
    initialization, the general status, a spin-up when stopped (waiting
    120 ticks) and write enable.
  - Attribute 2 gives the drive id (16#100 plus its low nibble); a caller
    with no geometry gets the three known drives'.
  - An unknown drive's multiply overwrites total_blocks.

  Returns:
    status_$ok: the drive came up
    status_$invalid_unit_number: a sub-unit other than 0
    an ANSI command's or win_$check_disk_status' status: a step failed
    status_$unrecognized_drive_id: an unknown drive

  Status stored: none.
}

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
