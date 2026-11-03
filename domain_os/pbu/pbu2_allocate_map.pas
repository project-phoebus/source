{ PBU2_$ALLOCATE_MAP - allocate I/O map space for a PBU unit.

  Image addresses:
    sau3  0x00E58AC4  PBU2_$ALLOCATE_MAP
    sau5  0x00E58AC4  PBU2_$ALLOCATE_MAP

  - IO_$ALLOC_MAP for the unit's I/O unit; its start is the result
    (unset when pbu_check_unit fails), recorded in the DCTE.

  Status stored:
    io_$alloc_map's status: the space was allocated, or not
    pbu_check_unit's status: the unit is not the caller's
    status_$pbu_iomap_already_allocated: the unit has map space
    status_$pbu_bad_parameter: length is not positive
    status_$pbu_not_supported: the unit is on the VME bus (`vme_bus')
}

function pbu2_$allocate_map(in unit: integer; in length: integer32;
                            in fixed: boolean; in iova: linteger;
                            out status: status_$t): integer32;
var
  dcte: pbu_$dcte_ptr_t;
  start: linteger;
begin
  dcte := pbu_check_unit(unit, status);
  if status.all <> status_$ok then
    return;
  if dcte^.flags.map_allocated then
    status.all := status_$pbu_iomap_already_allocated
  else if length <= 0 then
    status.all := status_$pbu_bad_parameter
%if vme_bus %then
  else if dcte^.unit_info.bus = io_$bus_vme then
    status.all := status_$pbu_not_supported
%endif
  else begin
    start := io_$alloc_map(dcte^.unit_info.io_unit, length, fixed, iova,
                           status);
    pbu2_$allocate_map := start;
    if status.all = status_$ok then begin
      dcte^.map_page := start div 1024;
      dcte^.map_start := start;
      dcte^.map_end := start + ((length + 1022) div 1024 + 1) * 1024;
      dcte^.flags.map_allocated := true;
    end;
  end;
end;
