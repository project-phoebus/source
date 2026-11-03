{ PBU_$FREE - free I/O map space a kernel driver's unit allocated.

  Image addresses:
    sau3  0x00E58EFA  PBU_$FREE
    sau5  0x00E590C8  PBU_$FREE
    sau8  0x03C617DA  PBU_$FREE

  - Under the exclusion lock: IO_$FREE of the space at iova (a failure
    crashes the system), and its npages I/O map entries cleared.
  - Without the I/O map space (`io_regions') no entries are cleared.

  Status stored:
    status_$ok: the space was freed
    pbu_check_unit's status: the unit is not the caller's
}

procedure pbu_$free(unit: integer; iova: linteger; npages: integer;
                    out status: status_$t);
  options(val_param);
var
  dcte: pbu_$dcte_ptr_t;
begin
  dcte := pbu_check_unit(unit, status);
  if status.all <> status_$ok then
    return;
  ml_$exclusion_start(pbu_$exclusion_lock);
  io_$free(dcte^.unit_info.io_unit, iova, status);
  if status.all <> status_$ok then
    crash_system(status);
%if io_regions %then
  pbu_clear_iomap(dcte^.unit_info.bus, iova, npages);
%endif
  ml_$exclusion_stop(pbu_$exclusion_lock);
end;
