{ ring_8025_stop_rcv - take a unit off line and end its receive process.

  Image addresses:
    sau7  0x3C49694C  ring_8025_stop_rcv
    sau8  0x03C89FA2  ring_8025_stop_rcv
    sau9  0x3C485BA6  ring_8025_stop_rcv

  - Clears the unit's online flag and waits 4 ticks; a running receive
    process is woken and waited for until it exits.

  Status stored: none.
}

procedure ring_8025_stop_rcv(u: ring_8025_$unit_ptr_t); internal;
var
  exit_val: integer32;
begin
  exit_val := ec_$read(u^.rcv_exit_ec) + 1;
  u^.flags := u^.flags - [r8025_unit_online];
  ring_8025_wait(4);
  if r8025_unit_rcv_proc in u^.flags then begin
    ec_$advance(u^.rcv_wake_ec);
    discard(ec_$wait(addr(u^.rcv_exit_ec), addr(ec_$nil_ec),
                     addr(ec_$nil_ec), exit_val, 1, 1));
  end;
  u^.flags := u^.flags - [r8025_unit_rcv_proc];
end;
