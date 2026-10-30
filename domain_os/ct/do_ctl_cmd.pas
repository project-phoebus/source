{ DO_CTL_CMD - start a control command on the tape controller.

  Image addresses:
    sau5  0x00E77228  DO_CTL_CMD

  - Under the controller's lock (unless the count is ct_count_unlocked,
    one block without it), the count, the go byte and the command code
    go into the controller's window.
  - The command is marked outstanding with the eventcount value its
    interrupt will reach.

  Returns:
    0: always (the callers test it)

  Status stored: none.
}

function do_ctl_cmd(in ctl_cmd: integer; in ctl_count: integer): integer32;
var
  n: integer;
  status: integer32;
begin
  n := ctl_count;
  if n <> ct_count_unlocked then
    ml_$lock(ct_dcte^.disk_error_que_hi)
  else
    n := 1;
  ct_count := n;
  if ct_count = 0 then
    ct_count := 1;
  ct_cmd := ctl_cmd;
  status := 0;
  with ct_regs^ do begin
    count := n;
    go := 1;
    cmd := ctl_cmd;
  end;
  ct_wait_value := ct_ec.value + 1;
  ct_busy := true;
  ct_state := ct_state_none;
  do_ctl_cmd := status;
  if ctl_count <> ct_count_unlocked then
    ml_$unlock(ct_dcte^.disk_error_que_hi);
end;
