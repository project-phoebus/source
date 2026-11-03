{ IO_$FREE_MAP_REGION - free one I/O map region recorded for a unit.

  Image addresses:
    sau3  0x00E19FC4  IO_$FREE_MAP_REGION
    sau4  0x0F81BB72  IO_$FREE_MAP_REGION
    sau5  0x00E1B28E  IO_$FREE_MAP_REGION
    sau8  0x03C1BF66  IO_$FREE_MAP_REGION

  - The region of the unit's list that starts at iova is freed
    (IO_$FREE) and its node returned.  With the PBU only.
  - A failed io_$check_unit's status is replaced by "iomap not
    allocated".
  - Without the region list (`io_regions') nothing is freed: the status
    is status_$pbu_not_supported.

  Status stored:
    status_$ok: the region was freed
    status_$pbu_iomap_not_allocated: no such region, or the unit is not
      good
    status_$pbu_not_supported: without the region list
}

procedure io_$free_map_region(unit: io_$unit_num_t; iova: linteger;
                              out status: status_$t);
  options(val_param);
%if io_regions %then
var
  p: io_$region_ptr_t;
begin
  if io_$check_unit(unit, status) then
    with io_$dctes[unit] do begin
      p := regions;
      while p <> nil do begin
        if p^.start = iova then begin
          io_$free(unit, iova, status);
          io_$remove_region(io_$dctes[unit], p);
          status.all := status_$ok;
          return;
        end;
        p := p^.next;
      end;
    end;
  status.all := status_$pbu_iomap_not_allocated;
end;
%else
begin
  status.all := status_$pbu_not_supported;
end;
%endif
