{ IO_$DISABLE_DEVICE - disable a unit's device through its bus.

  Image addresses:
    sau2  0x00E1A7E8  IO_$DISABLE_DEVICE
    sau3  0x00E19896  IO_$DISABLE_DEVICE
    sau4  0x0F81B466  IO_$DISABLE_DEVICE
    sau5  0x00E1AB46  IO_$DISABLE_DEVICE
    sau6  0x7801C100  IO_$DISABLE_DEVICE
    sau7  0x3C41E364  IO_$DISABLE_DEVICE
    sau8  0x03C1B980  IO_$DISABLE_DEVICE

  - The bus's disable_device routine with the unit's interrupt id, when
    the bus has one (nil on every SAU2 bus).

  Status stored:
    io_$check_unit's status: always
}

procedure io_$disable_device(unit: io_$unit_num_t; out status: status_$t);
  options(val_param);
begin
  if io_$check_unit(unit, status) then
    with io_$dctes[unit] do
      if io_$bus_epv[bus].disable_device <> nil then
        io_$bus_epv[bus].disable_device^(int.id);
end;
