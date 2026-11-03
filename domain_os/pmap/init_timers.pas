{ pmap_$init_timers - start the purifier and update timers.

  Image addresses:
    sau2  0x00E2F880  pmap_$init_timers
    sau4  0x0F832D78  pmap_$init_timers (module-local)
    sau9  0x3C435478  pmap_$init_timers (module-local)

  - Both timers go on the real-time queue, first due 229 ticks from now;
    a failure to enter one crashes the system.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure pmap_$init_timers;
var
  when: time_$clock_t;
  status: status_$t;
  now: integer32;
  first: integer32;
begin
  now := time_$clockh;

  { the purifier timer }
  pmap_$purifier_timer.flags := [1, 3, 4];
  pmap_$purifier_timer.callback := addr(pmap_$t_purif_callback);
  when.high := now;
  when.low := 0;
  first := now + 229;
  pmap_$purifier_timer.expire.high := first;
  pmap_$purifier_timer.expire.low := 0;
  pmap_$purifier_timer.interval.high16 := 0;
  pmap_$purifier_timer.interval.low32 := 468750;
  time_$q_enter_elem(time_$rteq, when, pmap_$purifier_timer, status);
  if status.all <> status_$ok then
    crash_system(status);

  { the update timer }
  pmap_$update_timer.flags := [1, 2, 4];
  pmap_$update_timer.callback := addr(pmap_$update_callback);
  when.high := now;
  when.low := 0;
  pmap_$update_timer.expire.high := first;
  pmap_$update_timer.expire.low := 0;
  pmap_$update_timer.interval.high := 229;
  pmap_$update_timer.interval.low := 0;
  time_$q_enter_elem(time_$rteq, when, pmap_$update_timer, status);
  if status.all <> status_$ok then
    crash_system(status);
end;
