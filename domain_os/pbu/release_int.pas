{ PBU_$RELEASE_INT - set down a kernel driver's PBU unit.

  Image addresses:
    sau3  0x00E59288  PBU_$RELEASE_INT
    sau5  0x00E59458  PBU_$RELEASE_INT
    sau8  0x03C61AB2  PBU_$RELEASE_INT

  - Undoes PBU_$ACQUIRE_INT: a unit the caller may use, or a publicly
    owned one with mode pbu_public, gets the current process as its
    owner and is set down (PBU_$SETDOWN).
  - With the AT bus's units (`pbu_atbus_units') the unit then joins
    PBU_$NONSYS_DEVICE.

  Status stored:
    pbu_$setdown's status: the unit was set down, or not
    pbu_check_unit's status: the unit is not the caller's
}

procedure pbu_$release_int(in unit: integer; in mode: integer;
                           out status: status_$t);
var
  dcte: pbu_$dcte_ptr_t;
  check_status: status_$t;
begin
  dcte := pbu_check_unit(unit, check_status);
  if (check_status.all = status_$ok) or else
     ((check_status.all = status_$pbu_unit_is_public) and then
      (mode = pbu_public)) then begin
    dcte^.owner := proc1_$current;
    pbu_$setdown(unit, nil, status);
%if pbu_atbus_units %then
    pbu_$nonsys_device := pbu_$nonsys_device + [unit];
%endif
  end
  else
    status := check_status;
end;
