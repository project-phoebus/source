{ RING_$KICK_DRIVER - wake both units' receive processes.

  Image addresses:
    sau2  0x00E768A8  RING_$KICK_DRIVER
    sau3  0x00E78098  RING_$KICK_DRIVER
    sau8  0x03C83190  RING_$KICK_DRIVER

  - Both units are marked busy and each initialized one's receive
    process woken.

  Status stored: none.
}

procedure ring_$kick_driver;
var
  i: integer;
begin
  for i := 0 to 1 do
    with ring_$ctl[i] do begin
      state_flags := state_flags + [ring_unit_busy];
      if initialized then
        ec_$advance(rx_wake_ec);
    end;
end;
