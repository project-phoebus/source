{ WIN_SEND_COMMAND - write a byte to the controller's command port.

  Image addresses:
    sau7  0x3C41BAD6  WIN_SEND_COMMAND

  - The port is waited for up to 10 times 20 ticks.
  - A start (start true) counts the block in the process's record for
    the drive, under the spin lock, and notes the chain's last block.
  - Another byte is given 65 ticks, then the status port is checked
    for a rejection.

  Status stored:
    status_$ok: the byte was written
    TIME_$WAIT's status: a wait was cut short
    status_$disk_controller_busy: the port did not get ready
    status_$disk_driver_logic_error: the controller rejected the byte
}

procedure win_send_command(in start: boolean; in cmd: integer;
                           in unit: integer; in out ctlr: win7_$ctlr_t;
                           out status: status_$t);
var
  regs: win7_$regs_ptr_t;
  i: integer;
  info: win7_$info_ptr_t;
  token: pinteger;
begin
  status.all := status_$ok;
  regs := ctlr.regs;
  if (regs^.cmd & win7_status_ready) = 0 then begin
    i := 0;
    repeat
      time_$wait(time_$relative, win7_ready_wait, status);
      i := i + 1;
    until (i = 10) or ((regs^.cmd & win7_status_ready) <> 0);
  end;
  if status.all <> status_$ok then
    return;

  if (regs^.cmd & win7_status_ready) <> 0 then begin
    if start then begin
      token := ml_$spin_lock(ctlr.spin);
      info := ctlr.cur^.info;
      with ctlr.procs[info^.req^.owner_op.owner][unit] do begin
        count := count + 1;
        if win7_cur_req^.next = nil then begin
          flags := flags + [15];
          regs^.cmd := cmd;
        end
        else
          regs^.cmd := cmd;
      end;
      ml_$spin_unlock(ctlr.spin, token);
    end
    else
      regs^.cmd := cmd;
    if not start then begin
      time_$wait(time_$relative, win7_cmd_wait, status);
      if (status.all = status_$ok) and
         ((regs^.cmd & win7_status_rejected) <> 0) then
        status.all := status_$disk_driver_logic_error;
    end;
  end
  else if status.all = status_$ok then
    status.all := status_$disk_controller_busy;
end;
