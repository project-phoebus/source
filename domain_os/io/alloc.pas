{ IO_$ALLOC - allocate I/O map space for a unit.

  Image addresses:
    sau2  0x00E1A9C2  IO_$ALLOC
    sau3  0x00E19D40  IO_$ALLOC
    sau5  0x00E1AFF0  IO_$ALLOC
    sau8  0x03C1BE12  IO_$ALLOC

  - With the PBU (`pbu_driver'): the length rounded up to 1024-byte
    pages, allocated anywhere in the bus's I/O map, or at iova when
    fixed; the result is the range's start.
  - With `pbu_alloc_mbus' the range is in the Multibus's map below
    1 MB, whatever the unit's bus.
  - With `pbu_alloc_atbus_windows' the range must be fixed, and a unit
    on the AT bus allocates in one of the bus's two memory windows,
    the one that holds iova.
  - Nothing is recorded in the region list.
  - Without it (the SAU2): a stub, the result 0.
  - The result is assigned only when a range is allocated.

  Status stored:
    status_$ok: the stub
    io_$alloc_region's status: the range was allocated, or not
    io_$check_unit's status: the unit is not good
    status_$pbu_bad_parameter: not fixed (`pbu_alloc_atbus_windows')
    status_$pbu_invalid_iova: an AT bus unit's iova in neither window
      (`pbu_alloc_atbus_windows')
}

function io_$alloc(unit: io_$unit_num_t; length: integer32;
                   fixed: boolean; iova: linteger;
                   out status: status_$t): integer32;
  options(val_param);
%if pbu_driver %then
var
%if pbu_alloc_atbus_windows %then
  hi: linteger;                           { the window }
  lo: linteger;
%endif
  pages: integer;
%endif
begin
%if pbu_driver %then
%if pbu_alloc_mbus %then
  if io_$check_unit(unit, status) then begin
    pages := (length + 1023) div 1024;
    io_$alloc := io_$alloc_region(io_$bus_mbus, 0, 16#100000, fixed, pages,
                                  iova, status);
  end;
%elseif pbu_alloc_atbus_windows %then
  if io_$check_unit(unit, status) then
    with io_$dctes[unit] do begin
      pages := (length + 1023) div 1024;
      if not fixed then begin
        status.all := status_$pbu_bad_parameter;
        io_$alloc := 0;
        return;
      end;
      if bus = io_$bus_atbus then begin
        if (iova >= 16#80000) and then (iova < 16#100000) then begin
          lo := 16#80000;
          hi := 16#100000;
        end
        else if (iova >= 16#900000) and then (iova < 16#1000000) then begin
          lo := 16#900000;
          hi := 16#1000000;
        end
        else begin
          status.all := status_$pbu_invalid_iova;
          io_$alloc := 0;
          return;
        end;
        io_$alloc := io_$alloc_region(bus, lo, hi, fixed, pages, iova,
                                      status);
      end
      else
        io_$alloc := io_$alloc_region(bus, 0, 16#FFFFFFFF, fixed, pages,
                                      iova, status);
    end;
%else
  if io_$check_unit(unit, status) then
    with io_$dctes[unit] do begin
      pages := (length + 1023) div 1024;
      io_$alloc := io_$alloc_region(bus, 0, 16#FFFFFFFF, fixed, pages,
                                    iova, status);
    end;
%endif
%else
  status.all := status_$ok;
  io_$alloc := 0;
%endif
end;
