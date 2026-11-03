{ ring_$do_start - start a unit's receive process and wait for it.

  Image addresses:
    sau2  0x00E7671C  ring_$do_start (module-local)
    sau8  0x03C83006  ring_$do_start (module-local)

  - The receive process (RING_$RCV0 or RING_$RCV1) is created and its
    first advance of the ready eventcount waited for, two clock ticks at
    most; a time-out crashes the system.
  - The unit is marked started even when the process could not be
    created.

  Status stored:
    proc1_$create_p's status: the unit was not started yet
    status_$ok: it was started already
}

procedure ring_$do_start(unit: integer; var u: ring_$unit_t;
                         out status: status_$t);
  internal;
var
  clock_val: integer32;
  ready_val: integer32;
begin
  if not (ring_unit_started in u.state_flags) then begin
    ready_val := ec_$read(u.ready_ec) + 1;
    discard(proc1_$create_p(ring_$rcv_proc[unit], 16#8000007, status));
    if status.all = 0 then begin
      clock_val := ec_$read(time_$clockh_ec) + 2;
      if ec_$wait(addr(u.ready_ec), addr(time_$clockh_ec),
                  addr(ec_$nil_ec), ready_val, clock_val, 0) <> 0 then
        crash_system(status_$network_receive_process_failed_to_start);
    end;
    u.state_flags := u.state_flags + [ring_unit_started];
  end
  else
    status.all := 0;
end;
