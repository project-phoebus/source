{ wait_for_controller - wait for the controller to drop its busy bit, then
  report whether the drive is ready.

  Image addresses:
    sau2  0x00E190BC  wait_for_controller (module-local)

  - A spin of up to three clock ticks on the busy bit (15); a drive not
    ready (bit 7) counts in WIN_$CNT and has its command taken down.

  Returns:
    status_$ok: ready
    status_$disk_controller_busy: still busy
    status_$disk_not_ready: not ready

  Status stored: none.
}

function wait_for_controller(unit: pinteger): integer32; internal;
var
  deadline: integer32;
  regs: win_$regs_ptr_t;
begin
  deadline := time_$clockh + 3;
  regs := win_units[unit].regs;

  { spin while busy, up to the deadline }
  repeat
  until ((regs^.status & 16#8000) = 0) or else (deadline < time_$clockh);

  if (regs^.status & 16#8000) = 0 then
    wait_for_controller := status_$ok
  else
    wait_for_controller := status_$disk_controller_busy;

  { a drive not ready }
  if (regs^.status & 16#80) <> 0 then begin
    win_$cnt.not_ready := win_$cnt.not_ready + 1;
    regs^.go := 0;
    wait_for_controller := status_$disk_not_ready;
  end;
end;
