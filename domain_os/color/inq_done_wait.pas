{ COLOR_$INQ_DONE_WAIT - wait for the color board's instruction queue.

  Image addresses:
    sau4  0x0F87B4AE  COLOR_$INQ_DONE_WAIT
    sau5  0x00E73092  COLOR_$INQ_DONE_WAIT

  - Only when the board is ready (status member 12): the queue's
    interrupt is enabled while the routine waits, up to 20 ticks.
  - A time-out, or a queue still busy after the wait, resets the board.

  Status stored:
    status_$ok: the queue is done, or the board is not ready
    status_$color_iq_done_wait_timed_out: the board was reset
}

procedure color_$inq_done_wait(out status: status_$t);
var
  ec_value: integer32;
  clock_value: integer32;
  timed_out: boolean;
begin
  status.all := status_$ok;
  if 12 in color_sup.status then begin
    ec_value := color_$iq_done_ec.value + 1;
    clock_value := time_$clockh + 20;
    color_sup.int_ctl := color_sup.int_ctl + [1];
    if 13 in color_sup.status then begin
      timed_out := ec_$wait(addr(color_$iq_done_ec), addr(time_$clockh_ec),
                            addr(ec_$nil_ec), ec_value, clock_value, 0)
                   <> 0;
      if timed_out or else (13 in color_sup.status) then begin
        color_sup.command := 9;
        color_sup.command := 8;
        color_sup.command := color_cmd_display_on;
        repeat
        until not (13 in color_sup.status);
        status.all := status_$color_iq_done_wait_timed_out;
      end;
    end;
    color_sup.int_ctl := color_sup.int_ctl - [1];
  end;
end;
