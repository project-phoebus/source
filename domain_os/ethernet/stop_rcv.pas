{ ethernet_stop_rcv - take a unit off line and stop its receive process.

  Image addresses:
    sau6  0x7808782E  ethernet_stop_rcv
    sau7  0x3C491A04  ethernet_stop_rcv
    sau8  0x03C85200  ethernet_stop_rcv
    sau9  0x3C480E00  ethernet_stop_rcv

  - A running receive process is woken and waited for until it
    advances its exit eventcount; the wait has no time-out.

  Status stored: none.
}

procedure ethernet_stop_rcv(u: ethernet_$unit_ptr_t); internal;
var
  exit_val: integer32;
begin
  exit_val := ec_$read(u^.rcv_exit_ec) + 1;
  u^.flags := u^.flags - [eth_unit_online];
  if eth_unit_rcv_proc in u^.flags then begin
    ec_$advance(u^.rcv_wake_ec);
    discard(ec_$wait(addr(u^.rcv_exit_ec), addr(ec_$nil_ec),
                     addr(ec_$nil_ec), exit_val, 1, 1));
  end;
  u^.flags := u^.flags - [eth_unit_rcv_proc];
end;
