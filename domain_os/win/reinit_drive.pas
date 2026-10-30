{ win_$reinit_drive - bring a drive up again and recalibrate it.

  Image addresses:
    sau2  0x00E194B4  win_$reinit_drive (module-local)

  - With the current request put aside, DISK_INIT again; on success
    mode 16#0A, ANSI command 4 (REZERO), a wait of the eventcount or 40
    ticks, and a check.  The attempt counts in WIN_$KTHUNKD and the
    drive's position is forgotten.

  Returns:
    win_$check_disk_status's status: DISK_INIT succeeded
    disk_init's status: it failed

  Status stored: none.
}

{ TODO(pascal) twelve frame bytes in win_$reinit_drive

  The SAU2 code addresses four objects of the frame (w, out_byte,
  geometry, wait_val); the reserved slot, the register-held saved_req,
  status and regs and the 4-byte result variable take 20 bytes more.
  That leaves 12 of four open longwords (the result variable in one of
  them, its place uncertain), held by the stand-ins unused_14, unused_1c
  and unused_24 in frame order, the result taken to be the lowest (dpc
  puts it last).  What they were is not known. }

function win_$reinit_drive(unit: pinteger; dev_unit: pinteger): integer32;
  internal;
var
  saved_req: disk_$io_req_ptr_t;
  status: integer32;
  regs: win_$regs_ptr_t;
  unused_14: integer32;                   { never addressed: the TODO }
  geometry: win_$geometry_t;
  unused_1c: integer32;                   { never addressed: the TODO }
  wait_val: integer32;
  unused_24: integer32;                   { never addressed: the TODO }
  w: pinteger;
  out_byte: win_$byte_t;
begin
  { the current request put aside }
  saved_req := win_cur_req;
  win_cur_req := nil;

  status := disk_init(unit, dev_unit, win_total_blocks, w, w, geometry, w);
  if status = status_$ok then begin
    { REZERO }
    regs := win_units[unit].regs;
    regs^.mode := 16#0A;
    wait_val := win_unit_ec[unit].value + 1;
    discard(win_$ansi_command(unit, 4, chr(0), out_byte));

    { the interrupt, or 40 ticks }
    discard(ec_$wait(addr(win_unit_ec[unit]),
                     ec_$eventcount_ptr_t(addr(time_$clockh)),
                     addr(ec_$nil_ec), wait_val, time_$clockh + 40, 0));

    status := win_$check_disk_status(unit);
  end;

  win_$kthunkd := win_$kthunkd + 1;
  win_cur_cyl := -1;
  win_cur_head := -1;
  win_cur_req := saved_req;
  win_$reinit_drive := status;
end;
