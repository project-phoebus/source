{ ring_8025_wait - wait for a number of clock ticks.

  Image addresses:
    sau8  0x03C89022  ring_8025_wait
    sau9  0x3C484C22  ring_8025_wait

  - Waits on the high clock's eventcount, four of its counts a tick.
}

procedure ring_8025_wait(ticks: integer); internal;
begin
  discard(ec_$waitn(addr(time_$clockh_ec),
                    ec_$read(time_$clockh_ec) + ticks * 4, 1));
end;
