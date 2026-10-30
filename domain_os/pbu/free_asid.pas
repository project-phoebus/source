{ PBU_$FREE_ASID - free an address space's PBU state.

  Image addresses:
    sau2  0x00E590F8  PBU_$FREE_ASID
    sau5  0x00E5A73E  PBU_$FREE_ASID

  - With the driver (`pbu_driver'), every unit is set down
    (PBU_$SETDOWN's statuses ignored) but the SM_ controller's unit
    while its DCTE exists.  Where the PBU support is configured out (the
    SAU2), nothing.  Neither body reads asid.

  Status stored: none.
}

%if pbu_driver %then
procedure pbu_$free_asid(asid: integer); options(val_param);
var
  unit: integer;
  setdown_unit: integer;
  status: status_$t;
begin
  for unit := 0 to pbu_$max_unit do begin
    if unit = pbu_sm_unit then begin
      discard(io_$get_dcte(io_ctype_smd, 0, status));
      if status.all = status_$ok then
        next;
    end;
    setdown_unit := unit;
    pbu_$setdown(setdown_unit, nil, status);
  end;
end;
%else
procedure pbu_$free_asid(asid: integer); options(val_param);
begin
end;
%endif
