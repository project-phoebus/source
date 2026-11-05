{ IO_$ENABLE_DEVICE - enable a unit's device through its bus.

  Image addresses:
    sau2  0x00E1A83E  IO_$ENABLE_DEVICE
    sau3  0x00E198EC  IO_$ENABLE_DEVICE
    sau4  0x0F81B4BC  IO_$ENABLE_DEVICE
    sau5  0x00E1AB9C  IO_$ENABLE_DEVICE
    sau6  0x7801C158  IO_$ENABLE_DEVICE
    sau7  0x3C41E3BC  IO_$ENABLE_DEVICE
    sau8  0x03C1B9D8  IO_$ENABLE_DEVICE

  - The bus's enable_device routine with the unit's interrupt id, when
    the bus has one (nil on every SAU2 bus).

  Status stored:
    io_$check_unit's status: always
}

procedure io_$enable_device(unit: io_$unit_num_t; out status: status_$t);
  options(val_param);
begin
  if io_$check_unit(unit, status) then
    with io_$dctes[unit] do
      if io_$bus_epv[bus].enable_device <> nil then
        io_$bus_epv[bus].enable_device^(int.id);
end;
