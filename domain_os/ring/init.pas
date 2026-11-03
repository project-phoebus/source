{ RING_$INIT - initialize a ring unit from its DCTE.

  Image addresses:
    sau2  0x00E2FAE0  RING_$INIT
    sau3  0x00E2E768  RING_$INIT
    sau5  0x00E31012  RING_$INIT
    sau8  0x03C32A54  RING_$INIT
    sau9  0x3C43594C  RING_$INIT

  - The unit's eventcounts and locks are initialized and its channels
    closed; a controller that probes well gets a NET_IO port, and with
    it the unit is marked initialized.

  Returns:
    0: the unit was initialized
    ring_$init_internal's status: the probe failed
    net_io_$create_port's status: no port

  Status stored: none.
}

{ TODO(pascal) 12 frame bytes of RING_$INIT

  The SAU2 image's frame is 28 bytes: the locals and the result variable
  account for 16.  dpc's layout of these locals has not been compared;
  the stand-ins unused_18 and unused_1c hold the other 12 (one 12-byte
  object would be placed at a multiple of 8 and lengthen the frame). }

[section(os_init_proc, os_init_data)]
function ring_$init(var dcte: dcte_t): integer32;
var
  status: status_$t;
  unit: ring_$unit_ptr_t;
  port: integer;
  i: integer;
  unused_18: array[1..2] of integer32;    { stand-in: the TODO above }
  unused_1c: integer32;
begin
  unit := addr(ring_$ctl[dcte.cnum]);
  ring_$driver.network_uid := ring_$network_uid;
  unit^.device_info := addr(dcte);

  ec_$init(unit^.rx_wake_ec);
  ec_$init(unit^.tx_ec);
  ec_$init(unit^.ready_ec);
  ml_$exclusion_init(unit^.tx_exclusion);
  ml_$exclusion_init(unit^.rx_exclusion);

  for i := 1 to 10 do
    unit^.channels[i].flags := false;

  status.all := ring_$init_internal(unit^, dcte);
  if status.all = 0 then begin
    port := net_io_$create_port(route_$port_type_ring, dcte.cnum,
                                addr(ring_$driver), 0, status);
    ring_$port_array[dcte.cnum] := port;
    unit^.route_port := addr(route_$port[port]);
    if status.all = 0 then
      unit^.initialized := true;
  end;

  { the join: the result is already in D0 }
  ring_$init := status.all;
end;
