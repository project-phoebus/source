{ IO_$FREE_MAP - free all the I/O map space recorded for a unit.

  Image addresses:
    sau3  0x00E19F46  IO_$FREE_MAP
    sau4  0x0F81BAF4  IO_$FREE_MAP
    sau5  0x00E1B210  IO_$FREE_MAP
    sau6  0x7801C7B2  IO_$FREE_MAP
    sau7  0x3C41EACE  IO_$FREE_MAP
    sau8  0x03C1BF54  IO_$FREE_MAP

  - Each region of the unit's list, the head first, is freed (IO_$FREE;
    a failure crashes the system) and its node returned
    (io_$remove_region).  With the PBU only.
  - Without the region list (`io_regions') nothing is freed: the status
    is status_$pbu_not_supported.

  Status stored:
    io_$free's status: the regions were freed
    io_$check_unit's status: the unit is not good
    status_$pbu_iomap_not_allocated: the unit has no regions
    status_$pbu_not_supported: without the region list
}

procedure io_$free_map(unit: io_$unit_num_t; out status: status_$t);
  options(val_param);
%if io_regions %then
var
  p: io_$region_ptr_t;
begin
  if io_$check_unit(unit, status) then
    with io_$dctes[unit] do
      if regions = nil then
        status.all := status_$pbu_iomap_not_allocated
      else
        repeat
          p := regions;
          io_$free(unit, p^.start, status);
          if status.all <> status_$ok then
            crash_system(status_$io_region_crash);
          io_$remove_region(io_$dctes[unit], p);
        until regions = nil;
end;
%else
begin
  status.all := status_$pbu_not_supported;
end;
%endif
