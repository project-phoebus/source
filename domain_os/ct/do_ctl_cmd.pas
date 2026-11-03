%if ct_atbus_qic02 %then
{ DO_CTL_CMD - give the tape drive a command, ctl_count times.

  Image addresses:
    sau8  0x03C7A60E  DO_CTL_CMD

  - With the AT bus adapter (`ct_atbus_qic02'), under the controller's
    lock but for ct_count_unlocked: the command byte is written with
    the request; once the adapter shows ready the request is dropped
    with the interrupts off, the drive must drop ready within 52800
    polls, and the interrupt is enabled (PBU_$ENABLE_DEVICE).  Each
    repetition but the last is waited for (CT_WAIT, 480 ticks, again
    while it times out); ct_blocks counts the commands given.
  - When the adapter shows an exception instead of ready, a read status
    command is given first, then the command again.
  - The result is 0: a failure is not passed on.

  Status stored: none.
}

function do_ctl_cmd(in ctl_cmd: integer; in ctl_count: integer): integer32;
label
  1, 2;
var
  n: integer;
  st: status_$t;
  saved_count: integer;
  saved_cmd: integer;
  timeout: integer32;
  status: integer32;
  regs: ct_$atbus_regs_ptr_t;
  i: integer;
  j: integer32;
  ready: boolean;
begin
1:
  n := ctl_count;
  if n <> ct_count_unlocked then
    ml_$lock(ct_dcte^.disk_error_que_hi)
  else
    n := 1;
  ct_count := n;
  if ct_count = 0 then
    ct_count := 1;
  ct_cmd := ctl_cmd;
  st.all := status_$ok;
  saved_count := 0;
  saved_cmd := 0;
  timeout := 16;
  status := 0;
  ct_blocks := 0;
  regs := ct_regs;
  if ct_cmd = ct_cmd_read_status then
    ct_ignore_exception := true
  else if not ct_wait_ready(timeout, st) then begin
    if regs^.stat.no_exception then
      goto 2;
    { an exception pending: a read status command first }
    ct_ignore_exception := true;
    st.all := status;
    saved_cmd := ct_cmd;
    saved_count := ct_count;
    ct_cmd := ct_cmd_read_status;
    ct_count := 1;
  end;
  for i := 1 to ct_count do begin
    ct_busy := true;
    regs^.data := ct_cmd;
    regs^.ctl := ct_ctl_request;
    if not ct_wait_ready(timeout, st) then
      goto 2;
    ct_state := ct_state_none;
    ct_wait_value := ct_ec.value + 1;
    disable;
    regs^.ctl := 0;
    for j := 1 to 52800 do
      if regs^.stat.not_ready then begin
        ready := false;
        exit;
      end
      else
        ready := true;
    if ready then begin
      enable;
      st.all := status_$ct_controller_timeout;
      goto 2;
    end;
    regs^.ctl := ct_ctl_int_enable;
    enable;
    pbu_$enable_device(ct_pbu_unit, st);
    if st.all <> status_$ok then
      goto 2;
    if i <> ct_count then begin
      repeat
        st.all := ct_wait(480, false);
      until st.all <> status_$ct_controller_timeout;
      if st.all <> status_$ok then
        st.all := status_$ok;
    end;
    ct_blocks := ct_blocks + 1;
  end;
2:
  if ctl_count <> ct_count_unlocked then
    ml_$unlock(ct_dcte^.disk_error_que_hi);
  if st.all = status_$ok then begin
    if saved_cmd <> 0 then begin
      discard(ct_wait(480, false));
      ct_cmd := saved_cmd;
      ct_count := saved_count;
      goto 1;
    end;
    status := st.all;
  end;
  do_ctl_cmd := status;
end;
%else
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
%endif
