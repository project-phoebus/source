{ IO_$ALLOC_MAP - allocate I/O map space for a unit and record it.

  Image addresses:
    sau5  0x00E1B12E  IO_$ALLOC_MAP

  - The pages a buffer of length bytes can span, in its bus's map below
    1 MB (64 KB without io_$attr_wide_iomap), go into the unit's region
    list (io_$add_region); the result is the region's start.
  - The result is assigned only when the region is allocated.

  Status stored:
    io_$alloc_region's status: the unit and length are good
    io_$check_unit's status: the unit is not good
    status_$pbu_not_supported: a unit on the VME bus
    status_$pbu_bad_parameter: a length of 0 or less
}

function io_$alloc_map(unit: io_$unit_num_t; length: integer32;
                       fixed: boolean; iova: linteger;
                       out status: status_$t): integer32;
  options(val_param);
var
  lo: linteger;
  pages: integer32;
  hi: linteger;
  va: linteger;
begin
  if io_$check_unit(unit, status) then
    with io_$dctes[unit] do
      if bus = io_$bus_vme then
        status.all := status_$pbu_not_supported
      else if length <= 0 then
        status.all := status_$pbu_bad_parameter
      else begin
        pages := (length + 16#3FE) div 1024 + 1;
        lo := 0;
        hi := 16#100000;
        if not (io_$attr_wide_iomap in attrs) then
          hi := 16#10000;
        if hi div 1024 + 1 = pages then
          pages := pages - 1;
        va := io_$alloc_region(bus, lo, hi, fixed, pages, iova, status);
        if status.all = status_$ok then begin
          io_$alloc_map := va;
          io_$add_region(io_$dctes[unit], va div 1024, va,
                         pages * 1024 + va);
        end;
      end;
end;
