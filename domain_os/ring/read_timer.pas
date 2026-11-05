{ ring_$read_timer - how far one of the controller's counters has counted.

  Image addresses:
    sau7  0x3C48DCCC  ring_$read_timer (module-local)
    sau8  0x03C814CC  ring_$read_timer (module-local)
    sau9  0x3C47D0CC  ring_$read_timer (module-local)

  - The counter's chip is given the read-back command for it, and its
    status, low and high bytes are read in turn (each in the high byte
    of the word).
  - A counter whose status says it has no count yet gives 16#FFFF; any
    other counter than the six crashes the system with
    status_$network_hardware_error.

  Returns:
    16#FFFF less the counter's value: the count since it was started
      from 16#FFFF

  Status stored: none.
}

function ring_$read_timer(var regs: ring8_$csr_t; timer: integer):
  pinteger;
  internal;
var
  status: pinteger;
  lsb: pinteger;
  msb: pinteger;
  count: pinteger;
begin
  case timer of
    ring8_cnt_rx_hdr: begin
      regs.timer_a_ctl := 16#C200;
      status := regs.timer_a[0];
      lsb := regs.timer_a[0];
      msb := regs.timer_a[0];
    end;
    ring8_cnt_rx_data: begin
      regs.timer_a_ctl := 16#C400;
      status := regs.timer_a[1];
      lsb := regs.timer_a[1];
      msb := regs.timer_a[1];
    end;
    ring8_cnt_rx_limit: begin
      regs.timer_a_ctl := 16#C800;
      status := regs.timer_a[2];
      lsb := regs.timer_a[2];
      msb := regs.timer_a[2];
    end;
    ring8_cnt_tx_hdr: begin
      regs.timer_b_ctl := 16#C200;
      status := regs.timer_b[0];
      lsb := regs.timer_b[0];
      msb := regs.timer_b[0];
    end;
    ring8_cnt_tx_end: begin
      regs.timer_b_ctl := 16#C400;
      status := regs.timer_b[1];
      lsb := regs.timer_b[1];
      msb := regs.timer_b[1];
    end;
    ring8_cnt_b_2: begin
      regs.timer_b_ctl := 16#C800;
      status := regs.timer_b[2];
      lsb := regs.timer_b[2];
      msb := regs.timer_b[2];
    end;
    otherwise begin
      crash_system(status_$network_hardware_error);
    end;
  end;

  if (status & 16#4000) <> 0 then
    ring_$read_timer := 16#FFFF
  else begin
    count := (msb & 16#FF00) + rshft(lsb & 16#FF00, 8);
    ring_$read_timer := 16#FFFF - count;
  end;
end;
