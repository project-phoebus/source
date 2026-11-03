{ PBU_$FAULTED_UNITS - report the faulted PBU units.

  Image addresses:
    sau2  0x00E590FA  PBU_$FAULTED_UNITS
    sau3  0x00E5A2BA  PBU_$FAULTED_UNITS
    sau5  0x00E5A79C  PBU_$FAULTED_UNITS
    sau8  0x03C62BF6  PBU_$FAULTED_UNITS

  - With the driver (`pbu_driver'), the set, as a word, of the units the
    caller may use whose DCTE is marked faulted.  Where the PBU support
    is configured out (the SAU2), 0.

  Status stored:
    status_$ok: with the driver
    status_$pbu_not_present: without it
}

%if pbu_driver %then
function pbu_$faulted_units(out status: status_$t): integer;
var
  units: pbu_$unit_set_t;
  unit: integer;
  dcte: pbu_$dcte_ptr_t;
  check_status: status_$t;
begin
  status.all := status_$ok;
  units := [];
  for unit := 0 to pbu_$max_unit do begin
    dcte := pbu_check_unit(unit, check_status);
    if (check_status.all = status_$ok) and then dcte^.flags.faulted then
      units := units + [unit];
  end;
  pbu_$faulted_units := integer(units);
end;
%else
function pbu_$faulted_units(out status: status_$t): integer;
begin
  status.all := status_$pbu_not_present;
  pbu_$faulted_units := 0;
end;
%endif
