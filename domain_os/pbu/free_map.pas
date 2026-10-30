{ PBU_$FREE_MAP - free a PBU unit's I/O map space.

  Image addresses:
    sau5  0x00E5915A  PBU_$FREE_MAP

  - Undoes PBU2_$ALLOCATE_MAP: IO_$FREE_MAP (a failure crashes the
    system), and the space's I/O map entries cleared.

  Status stored:
    status_$ok: the space was freed
    pbu_check_unit's status: the unit is not the caller's
    status_$pbu_iomap_not_allocated: the unit has no map space
}

procedure pbu_$free_map(in unit: integer; out status: status_$t);
var
  dcte: pbu_$dcte_ptr_t;
  npages: integer32;
begin
  dcte := pbu_check_unit(unit, status);
  if status.all <> status_$ok then
    return;
  if not dcte^.flags.map_allocated then begin
    status.all := status_$pbu_iomap_not_allocated;
    return;
  end;
  io_$free_map(dcte^.unit_info.io_unit, status);
  if status.all <> status_$ok then
    crash_system(status);
  dcte^.flags.map_allocated := false;
  npages := (dcte^.map_end + 1023 - dcte^.map_start) div 1024;
  pbu_clear_iomap(dcte^.unit_info.bus, dcte^.map_start, npages);
end;
