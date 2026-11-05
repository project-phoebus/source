{ PBU_$FREE_MAP - free a PBU unit's I/O map space.

  Image addresses:
    sau3  0x00E58F8C  PBU_$FREE_MAP
    sau5  0x00E5915A  PBU_$FREE_MAP
    sau6  0x78060E22  PBU_$FREE_MAP
    sau7  0x3C469878  PBU_$FREE_MAP
    sau8  0x03C61848  PBU_$FREE_MAP

  - Undoes PBU2_$ALLOCATE_MAP: IO_$FREE_MAP (a failure crashes the
    system), and the space's I/O map entries cleared.
  - With the DMA through the I/O map space (`pbu_dma_iomap') an AT bus
    unit's eight channel records then have their byte at +0x0A cleared
    (cleared_10).
  - Without the I/O map space (`io_regions') nothing is freed.

  Status stored:
    status_$ok: the space was freed
    pbu_check_unit's status: the unit is not the caller's
    status_$pbu_iomap_not_allocated: the unit has no map space
    status_$ok: always, without `io_regions'
}

%if io_regions %then
procedure pbu_$free_map(in unit: integer; out status: status_$t);
var
  dcte: pbu_$dcte_ptr_t;
  npages: integer32;
%if pbu_dma_iomap %then
  ch: integer;
%endif
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
%if pbu_dma_iomap %then
  if dcte^.unit_info.bus = io_$bus_atbus then
    for ch := 0 to 7 do
      pbu_$mapped_info[unit, ch].cleared_10 := false;
%endif
end;
%else
procedure pbu_$free_map(in unit: integer; out status: status_$t);
begin
  status.all := status_$ok;
end;
%endif
