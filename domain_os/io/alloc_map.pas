{ IO_$ALLOC_MAP - allocate I/O map space for a unit and record it.

  Image addresses:
    sau3  0x00E19E76  IO_$ALLOC_MAP
    sau4  0x0F81BA2E  IO_$ALLOC_MAP
    sau5  0x00E1B12E  IO_$ALLOC_MAP
    sau6  0x7801C6D0  IO_$ALLOC_MAP
    sau7  0x3C41E9C6  IO_$ALLOC_MAP
    sau8  0x03C1BF40  IO_$ALLOC_MAP

  - The pages a buffer of length bytes can span, in its bus's map below
    1 MB (64 KB without io_$attr_wide_iomap or with `mbus_map_64k'), go
    into the unit's region list; the result is the region's start.
  - With `mbus_map_64k' the region's page is its start's page plus 192.
  - With `io_atbus_map_windows' only an AT bus unit is allocated: in
    0..16#80000 for a bus master (io_$attr_bus_master), else from
    16#80000 to 16#90000, or to 16#A0000 with io_$attr_wide_iomap.  For
    a unit of another bus va is not assigned, and it is returned and
    recorded as the region.
  - The result is assigned only when the region is allocated.
  - Without the region list (`io_regions') nothing is allocated: the
    result is 0, the status status_$pbu_not_supported.

  Status stored:
    io_$alloc_region's status: the unit and length are good
    io_$check_unit's status: the unit is not good
    status_$pbu_not_supported: a unit on the VME bus (`vme_bus')
    status_$pbu_bad_parameter: a length of 0 or less
    status_$pbu_not_supported: without the region list
}

function io_$alloc_map(unit: io_$unit_num_t; length: integer32;
                       fixed: boolean; iova: linteger;
                       out status: status_$t): integer32;
  options(val_param);
%if io_regions %then
var
  lo: linteger;
  pages: integer32;
  hi: linteger;
  va: linteger;
begin
  if io_$check_unit(unit, status) then
    with io_$dctes[unit] do
%if vme_bus %then
      if bus = io_$bus_vme then
        status.all := status_$pbu_not_supported
      else
%endif
      if length <= 0 then
        status.all := status_$pbu_bad_parameter
      else begin
        pages := (length + 16#3FE) div 1024 + 1;
%if io_atbus_map_windows %then
        if bus = io_$bus_atbus then begin
          if io_$attr_bus_master in attrs then begin
            lo := 0;
            hi := 16#80000;
          end
          else begin
            lo := 16#80000;
            if io_$attr_wide_iomap in attrs then
              hi := 16#A0000
            else
              hi := 16#90000;
          end;
          if (hi - lo) div 1024 + 1 = pages then
            pages := pages - 1;
          va := io_$alloc_region(bus, lo, hi, fixed, pages, iova, status);
        end;
%else
        lo := 0;
%if mbus_map_64k %then
        hi := 16#10000;
%else
        hi := 16#100000;
        if not (io_$attr_wide_iomap in attrs) then
          hi := 16#10000;
%endif
        if hi div 1024 + 1 = pages then
          pages := pages - 1;
        va := io_$alloc_region(bus, lo, hi, fixed, pages, iova, status);
%endif
        if status.all = status_$ok then begin
          io_$alloc_map := va;
%if mbus_map_64k %then
          io_$add_region(io_$dctes[unit], va div 1024 + 192, va,
                         pages * 1024 + va);
%else
          io_$add_region(io_$dctes[unit], va div 1024, va,
                         pages * 1024 + va);
%endif
        end;
      end;
end;
%else
begin
  status.all := status_$pbu_not_supported;
  io_$alloc_map := 0;
end;
%endif
