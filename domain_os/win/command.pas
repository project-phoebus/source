{ win_$command - give the controller a command and wait for it.

  Image addresses:
    sau5  0x00E1996E  win_$command
    sau6  0x78019D9E  win_$command

  - The command byte goes to the controller's window; the wait is for
    WIN_$INT's advance of the eventcount, or 40 ticks (a time-out counted
    in WIN_$CNT).  With the descriptor-list controller only.

  Returns:
    win_$check_disk_status's status: the command completed
    status_$disk_controller_busy: a time-out

  Status stored: none.
}

function win_$command(ctlr: pinteger; cmd: integer): integer32;
  internal;
var
  wait_val: integer32;
begin
  wait_val := win_unit_ec[ctlr].value + 1;
  win_units[ctlr].regs^.command := cmd;

  { the interrupt, or 40 ticks }
  if ec_$wait(addr(win_unit_ec[ctlr]),
              ec_$eventcount_ptr_t(addr(time_$clockh)),
              addr(ec_$nil_ec), wait_val, time_$clockh + 40, 0) <> 0 then
  begin
    win_$cnt.w_0a := win_$cnt.w_0a + 1;
    win_$command := status_$disk_controller_busy;
  end
  else
    win_$command := win_$check_disk_status(ctlr);
end;
