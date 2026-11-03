{ TIME_$INIT - initialize the clocks and the time queues.

  Image addresses:
    sau2  0x00E2FE6C  TIME_$INIT
    sau4  0x0F8333E8  TIME_$INIT
    sau8  0x03C32DDC  TIME_$INIT
    sau9  0x3C435CD4  TIME_$INIT

  - The real-time queue and the 64 virtual-timer queues are set up and
    the two deferred-interrupt elements cleared.
  - When asked, the clocks, the boot time and the time of day are
    seeded from the calendar chip.  The tick period is set to normal and
    the hardware timers programmed (TIMER_$INIT; with `timer_dcte' the
    timer's DCTE does that instead, from IO_$INIT).

  Status stored: none.
}

{ TODO(pascal) TIME_$INIT's 6 frame bytes below i's slot

  The SAU2 frame has 6 bytes below the declared locals that nothing
  addresses: a count kept for the `for' loop, or read_calendar's
  register copy.  Nothing is declared for them. }

[section(os_init_proc, os_init_data)]
procedure time_$init(in read_calendar: boolean);
var
  secs: integer32;
  clock: time_$clock_t;
  i: integer;
begin
  { the queues and the deferred-interrupt elements }
  time_$q_init;
  time_$q_init_queue(false, 0, time_$rteq);
  for i := 1 to 64 do
    time_$q_init_queue(true, i, time_$vtq[i]);
  di_$init_q_elem(time_$di_vt);
  di_$init_q_elem(time_$di_rte);

  { the clocks from the calendar }
  if read_calendar then begin
    time_$read_cal(clock, secs);
    time_$clockh := clock.high;
    time_$clockl := clock.low;
    time_$current_clockh := clock.high;
    time_$current_clockl := clock.low;
    time_$boot_time := clock.high;
    time_$current_time.sec := secs + 315532800;
    time_$current_time.usec := 0;
    time_$current_skew := 0;
    time_$current_delta := 0;
  end;

  time_$current_tick := 4167;
%if not timer_dcte %then
  discard(timer_$init);
%endif
end;
