{ win_$wait_phase - wait for the controller to reach a phase.

  Image addresses:
    sau8  0x03C1A01A  win_$wait_phase (module-local)

  - The status port of controller 0 is polled until it reads the phase
    with 16#C0, for 20 ticks of the clock's high half.
  - A time-out notes the phase and the port's last value in the block.

  Returns:
    status_$ok: the phase was reached
    status_$disk_controller_timeout: it was not

  Status stored: none.
}

function win_$wait_phase(phase: integer): integer32; internal;
var
  regs: win_$regs_ptr_t;
  want: integer;
  deadline: integer32;
begin
  regs := win_units[0].regs;
  win_$wait_phase := status_$ok;
  want := phase ! 16#C0;
  deadline := time_$clockh + 20;
  repeat
    if regs^.status = want then
      return;
  until time_$clockh > deadline;
  if regs^.status <> want then begin
    win_$wait_phase := status_$disk_controller_timeout;
    win_last_status := regs^.status;
    win_last_phase := want;
  end;
end;
