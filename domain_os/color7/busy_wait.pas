{ COLOR7_$BUSY_WAIT - wait until the drawing engine is idle.

  Image addresses:
    sau7  0x3C48D218  COLOR7_$BUSY_WAIT

  - The engine's status is polled until both its fields are 0, up to
    1500 times, with a wait of 500 ticks (TIME_$WAIT) after each poll
    that finds it busy; the descriptor is not read.

  Status stored:
    status_$ok: the engine is idle
    color7_$busy_timeout: the polls ran out
}

[section(color7_wired_proc, wired_data)]
procedure color7_$busy_wait(dcte: color7_$dcte_ptr_t;
                            out status: status_$t);
  options(val_param);
var
  st: color7_$status_t;
  delay: time_$clock_t;
  i: integer;
begin
  delay.high := 0;
  delay.low := color7_$busy_delay;
  with color7_static do
    for i := 1 to color7_$busy_polls do begin
      st := color7_$status_reg_ptr_t(integer32(regs) +
                                    color7_$status_offset)^.status;
      if (st.queue = 0) and then (st.busy = 0) then begin
        status.all := status_$ok;
        return;
      end;
      time_$wait(time_$relative, delay, status);
    end;
  status.all := color7_$busy_timeout;
end;
