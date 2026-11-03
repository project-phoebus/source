{ IO_$CLEAR_PENDING - clear a unit's pending interrupt through its bus.

  Image addresses:
    sau2  0x00E1A798  IO_$CLEAR_PENDING
    sau3  0x00E19846  IO_$CLEAR_PENDING
    sau4  0x0F81B416  IO_$CLEAR_PENDING
    sau5  0x00E1AAF6  IO_$CLEAR_PENDING
    sau8  0x03C1B930  IO_$CLEAR_PENDING
    sau9  0x3C41D2E6  IO_$CLEAR_PENDING

  - The bus's clear_pending routine with the unit's interrupt id.

  Status stored:
    io_$check_unit's status: always
}

procedure io_$clear_pending(unit: io_$unit_num_t; out status: status_$t);
  options(val_param);
begin
  if io_$check_unit(unit, status) then
    with io_$dctes[unit] do
      io_$bus_epv[bus].clear_pending^(int.id);
end;
