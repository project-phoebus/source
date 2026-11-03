{ pbu_map_check_unit - find a PBU unit's DCTE at interrupt level.

  Image addresses:
    sau3  0x00E89BA4  pbu_map_check_unit (module-local)
    sau5  0x00E91F70  pbu_map_check_unit (module-local)
    sau8  0x03CA5664  pbu_map_check_unit (module-local)

  - The map's PBU_$PAGE_END marks its address.
  - No ownership test: a user handler runs for the unit's owner.  The
    result is the unit's DCTE, unset for an invalid unit number.

  Status stored:
    status_$ok: the unit is set up
    status_$pbu_invalid_unit_number: unit is not 0..15
    status_$pbu_unit_not_acquired: the unit is not set up
}

function pbu_map_check_unit(unit: integer; out status: status_$t):
  pbu_$dcte_ptr_t; internal;
var
  dcte: pbu_$dcte_ptr_t;
begin
  status.all := status_$ok;
  if (unit < 0) or else (unit > pbu_$max_unit) then
    status.all := status_$pbu_invalid_unit_number
  else begin
    dcte := pbu_$dctes[unit];
    if dcte = nil then
      status.all := status_$pbu_unit_not_acquired;
  end;
  pbu_map_check_unit := dcte;
end;
