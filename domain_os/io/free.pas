{ IO_$FREE - free I/O map space allocated for a unit.

  Image addresses:
    sau3  0x00E19DA6  IO_$FREE
    sau4  0x0F81B95E  IO_$FREE
    sau5  0x00E1B05E  IO_$FREE
    sau8  0x03C1BEFC  IO_$FREE

  - The range of the bus's map starting at iova is freed
    (io_$free_region, which crashes the system for a start it does not
    find).  With the PBU only.

  Status stored:
    io_$check_unit's status: always
}

procedure io_$free(unit: io_$unit_num_t; iova: linteger;
                   out status: status_$t);
  options(val_param);
begin
  if io_$check_unit(unit, status) then
    with io_$dctes[unit] do
      io_$free_region(bus, iova);
end;
