{ ct_check_unit - check that a request may use the tape unit.

  Image addresses:
    sau5  0x00E76F72  ct_check_unit (module-local)
    sau9  0x3C477C40  ct_check_unit (module-local)
    sau8  0x03C7A12E  ct_check_unit (module-local)

  Returns:
    0: the request may use the unit
    status_$ct_invalid_unit_number: a unit other than 0
    status_$ct_unit_not_acquired: the current process is not the owner
    status_$ct_operation_in_progress: a command is outstanding

  Status stored: none.
}

function ct_check_unit(unit: integer): integer32; internal;
begin
  if unit <> 0 then
    ct_check_unit := status_$ct_invalid_unit_number
%if ct_scsi %then
  else if proc1_$current <> ct_owner then
%else
  else if ct_owner <> proc1_$current then
%endif
    ct_check_unit := status_$ct_unit_not_acquired
  else if ct_busy then
    ct_check_unit := status_$ct_operation_in_progress
  else
    ct_check_unit := 0;
end;
