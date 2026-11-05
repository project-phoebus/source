{ pbu_check_unit - find a unit's DCTE and check that the caller may use
  it.

  Image addresses:
    sau3  0x00E5882C  pbu_check_unit (module-local)
    sau5  0x00E5882C  pbu_check_unit (module-local)
    sau6  0x780604A0  pbu_check_unit (module-local)
    sau7  0x3C4692A0  pbu_check_unit (module-local)
    sau8  0x03C61354  pbu_check_unit (module-local)

  - A publicly owned unit, a unit the current process owns and a global
    device are the caller's; the DCTE's current address space is then
    the caller's.
  - The result is the DCTE, unset for an invalid unit number.

  Status stored:
    status_$ok: the unit is the caller's
    status_$pbu_invalid_unit_number: unit is not 0..15
    status_$pbu_unit_not_acquired: the unit is not set up
    status_$pbu_unit_in_use: another process owns it
    status_$pbu_unit_is_public: the second test of the public sharing
      word passes
}

function pbu_check_unit(unit: integer; out status: status_$t):
  pbu_$dcte_ptr_t; internal;
var
  dcte: pbu_$dcte_ptr_t;
begin
  if (unit < 0) or else (unit > pbu_$max_unit) then
    status.all := status_$pbu_invalid_unit_number
  else begin
    dcte := pbu_$dctes[unit];
    if dcte = nil then
      status.all := status_$pbu_unit_not_acquired
    else if (dcte^.sharing = pbu_public) or else
            (dcte^.owner = proc1_$current) or else dcte^.flags.global then
    begin
      status.all := status_$ok;
      dcte^.unit_info.cur_asid := proc1_$as_id;
    end
    else if dcte^.sharing = pbu_public then
      status.all := status_$pbu_unit_is_public
    else
      status.all := status_$pbu_unit_in_use;
  end;
  pbu_check_unit := dcte;
end;
