{ PBU_$ALLOC - allocate I/O map space for a kernel driver's unit.

  Image addresses:
    sau5  0x00E5895E  PBU_$ALLOC

  - IO_$ALLOC for the unit's I/O unit, npages pages, at iova when fixed;
    the result is IO_$ALLOC's, unset when the check fails.

  Status stored:
    io_$alloc's status: the space was allocated, or not
    pbu_check_unit's status: the unit is not the caller's
}

function pbu_$alloc(unit: integer; fixed: boolean; npages: integer;
                    iova: linteger; out status: status_$t): integer32;
  options(val_param);
var
  dcte: pbu_$dcte_ptr_t;
begin
  dcte := pbu_check_unit(unit, status);
  if status.all = status_$ok then
    pbu_$alloc := io_$alloc(dcte^.unit_info.io_unit, npages * 1024, fixed,
                            iova, status);
end;
