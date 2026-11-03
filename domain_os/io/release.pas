{ IO_$RELEASE - release an acquired unit.

  Image addresses:
    sau2  0x00E1A6CE  IO_$RELEASE
    sau3  0x00E19766  IO_$RELEASE
    sau5  0x00E1AA16  IO_$RELEASE
    sau8  0x03C1B84E  IO_$RELEASE
    sau9  0x3C41D21A  IO_$RELEASE

  - The device is disabled through its bus (when it can be), the
    interrupt undefined, the unit's I/O map regions freed (IO_$FREE_MAP,
    with the PBU, `pbu_driver') and the slot freed.

  Status stored:
    io_$check_unit's status: no regions held
    io_$free_map's status: regions were freed
}

procedure io_$release(unit: io_$unit_num_t; out status: status_$t);
  options(val_param);
begin
  if io_$check_unit(unit, status) then
    with io_$dctes[unit] do begin
      if io_$bus_epv[bus].disable_device <> nil then
        io_$bus_epv[bus].disable_device^(int.id);
      io_$bus_epv[bus].define_int^(int.id, nil, nil);
%if pbu_driver %then
      if regions <> nil then
        io_$free_map(unit, status);
%endif
      tag := 0;
    end;
end;
