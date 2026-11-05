%if ct_atbus_qic02 %then
{ DO_CTL_CMD - give the tape drive a command, ctl_count times.

  Image addresses:
    sau7  0x3C4859D8  DO_CTL_CMD
    sau8  0x03C7A60E  DO_CTL_CMD

  - With the AT bus adapter (`ct_atbus_qic02'), under the controller's
    lock but for ct_count_unlocked: the command byte is written with
    the request; once the adapter shows ready the request is dropped
    with the interrupts off, the drive must drop ready within 52800
    polls, and the interrupt is enabled (PBU_$ENABLE_DEVICE).  Each
    repetition but the last is waited for (CT_WAIT, 480 ticks, again
    while it times out); ct_xfer_count counts the commands given.
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
  ct_xfer_count := 0;
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
    ct_xfer_count := ct_xfer_count + 1;
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
    sau6  0x7807DFB8  DO_CTL_CMD

  - Under the controller's lock (unless the count is ct_count_unlocked,
    one block without it), the count, the go byte and the command code
    go into the controller's window.
  - The command is marked outstanding with the eventcount value its
    interrupt will reach.
  - With the second controller (`win6_ct6_board') the command goes in a
    command block instead: one is taken (WIN6_$GET_IOPBS, tried again
    every 8 ticks, 21 times in all), filled with the operation
    ct6_map_cmd gives and the count, and started through the tape's
    start mailbox once the controller has taken the last start (a
    crash after 20 ticks).

  Returns:
    0: the command was started
    status_$ct_controller_timeout: no command block came free
    status_$ct_unrecognized_action_type: ct6_map_cmd failed

  Status stored: none.
}

function do_ctl_cmd(in ctl_cmd: integer; in ctl_count: integer): integer32;
%if win6_ct6_board %then
label
  10, 20;
%endif
var
  n: integer;
  status: integer32;
%if win6_ct6_board %then
  first: integer;
  last: integer;
  idx: integer;
  busy: boolean;
  free: boolean;
  r: integer;
  op: integer;
  deadline: integer32;
%endif
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
%if win6_ct6_board %then
  if ct6_page <> nil then begin
    { a command block, waiting 8 ticks at a time for one }
    busy := win6_$get_iopbs(1, first, last) <> 0;
    idx := first;
    if busy then begin
      for r := 1 to 20 do begin
        discard(ec_$wait(addr(time_$clockh_ec), addr(ec_$nil_ec),
                         addr(ec_$nil_ec), time_$clockh + 8, 0, 0));
        free := win6_$get_iopbs(1, first, last) = 0;
        idx := first;
        if free then
          goto 10;
      end;
      do_ctl_cmd := status_$ct_controller_timeout;
      goto 20;
    end;
10:
    if not ct6_map_cmd(ctl_cmd, op) then begin
      do_ctl_cmd := status_$ct_unrecognized_action_type;
      goto 20;
    end;
    with ct6_page^.iopbs[idx] do begin
      req := nil;
      status := -1;
      opu.op := op;
      state.count := n;
      state.kind := ct6_kind_started;
      opu.unused_72 := 0;
      opu.unit := 0;
      buf := 0;
      l_14 := 0;
      l_18 := 0;
      l_1c := 0;
    end;

    { the start, once the controller has taken the last one }
    with ct6_page^ do begin
      if tape_start.flag <> 0 then begin
        deadline := time_$clockh + 20;
        while tape_start.flag <> 0 do
          if time_$clockh > deadline then begin
            crash_system(status_$ct_controller_timeout);
            exit;
          end;
      end;
      tape_start_iopb := idx * win6_iopb_size;
      tape_start.flag := 1;
    end;
  end
  else
%endif
  with ct_regs^ do begin
    count := n;
    go := 1;
    cmd := ctl_cmd;
  end;
  ct_wait_value := ct_ec.value + 1;
  ct_busy := true;
  ct_state := ct_state_none;
  do_ctl_cmd := status;
%if win6_ct6_board %then
20:
%endif
  if ctl_count <> ct_count_unlocked then
    ml_$unlock(ct_dcte^.disk_error_que_hi);
end;
%endif
