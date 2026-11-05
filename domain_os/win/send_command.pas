{ win_$send_command - send the controller a command block.

  Image addresses:
    sau7  0x3C41CA12  win_$send_command (module-local)
    sau8  0x03C1A076  win_$send_command (module-local)

  - Once controller 0 is idle and then in the command phase, the block
    gets the command, the head, the cylinder and the sector (the drive
    and the count are the caller's), and its six bytes go out through
    the data port.

  Returns:
    status_$ok: the block was sent
    status_$disk_controller_busy: the controller was not idle
    status_$disk_controller_error: it did not take a command

  Status stored: none.
}

function win_$send_command(op: integer32; cyl: pinteger; head: integer;
                           sector: integer): integer32; internal;
var
  regs: win_$regs_ptr_t;
  ok: boolean;
  lo: integer;
  i: integer;
begin
  regs := win_units[0].regs;
  ok := win_$wait_phase(win_phase_idle) = status_$ok;
  if ok then begin
    regs^.select := 0;
    ok := win_$wait_phase(win_phase_command) = status_$ok;
    if ok then begin
      win_cmd.op := op;
      win_cmd.head := head;

      { the cylinder's bits 9..8 above the sector, its low byte after }
      win_cmd.cyl := cyl;
      lo := win_cmd.cyl_lo;
      win_cmd.cyl := lshft(win_cmd.cyl, 6);
      win_cmd.cyl_lo := lo;
      win_cmd.sector := sector;
      if cyl >= 1024 then
        win_cmd.cyl_10 := true
      else
        win_cmd.cyl_10 := false;

      if op = win_cmd_read_buffer then
        win_cmd.ctl := 0
      else
        win_cmd.step := 1;

      for i := 0 to 5 do
        regs^.data := win_cmd.bytes[i];
      win_$send_command := status_$ok;
    end
    else
      win_$send_command := status_$disk_controller_error;
  end
  else
    win_$send_command := status_$disk_controller_busy;
end;
