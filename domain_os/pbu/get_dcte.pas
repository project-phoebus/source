{ PBU_$GET_DCTE - copy a PBU unit's DCTE.

  Image addresses:
    sau5  0x00E591F8  PBU_$GET_DCTE

  - The DCTE's first max bytes, at most its 0x54, go to buf, and len is
    their number.  No ownership check: any process may read any unit's
    DCTE.
  - The unit's `< 0' test on the unsigned word takes 16#8000 and up as
    negative.

  Status stored:
    status_$ok: the DCTE was copied
    status_$pbu_invalid_unit_number: unit is not 0..15
    status_$pbu_unit_not_acquired: the unit is not set up
}

procedure pbu_$get_dcte(in unit: pinteger; out buf: univ pbu_$dcte_bytes_t;
                        in max: integer; out len: integer;
                        out status: status_$t);
var
  dcte: pbu_$dcte_ptr_t;
  i: integer;
begin
  status.all := status_$ok;
  if (unit < 0) or else (unit > pbu_$max_unit) then begin
    status.all := status_$pbu_invalid_unit_number;
    return;
  end;
  dcte := pbu_$dctes[unit];
  if dcte = nil then begin
    status.all := status_$pbu_unit_not_acquired;
    return;
  end;
  len := 84;
  if max < 16#54 then
    len := max;
  for i := 1 to len do
    buf[i] := pbu_$dcte_bytes_ptr_t(dcte)^[i];
end;
