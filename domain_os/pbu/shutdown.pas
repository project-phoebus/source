{ PBU_$SHUTDOWN - set down the PBU's user units at shutdown.

  Image addresses:
    sau3  0x00E59932  PBU_$SHUTDOWN
    sau5  0x00E59B9E  PBU_$SHUTDOWN
    sau6  0x78061852  PBU_$SHUTDOWN
    sau7  0x3C46A1B2  PBU_$SHUTDOWN
    sau8  0x03C62088  PBU_$SHUTDOWN

  - Every set-up unit with an owner and no kernel driver is set down,
    until one fails.
  - With the AT bus's units (`pbu_atbus_units') unit 3 is left set up.

  Status stored:
    pbu_$setdown's status: the last unit set down
}

procedure pbu_$shutdown(out status: status_$t);
var
  unit: integer;
  dcte: pbu_$dcte_ptr_t;
  setdown_unit: integer;
begin
  for unit := 0 to pbu_$max_unit do begin
%if pbu_atbus_units %then
    if unit = pbu_shutdown_kept_unit then
      next;
%endif
    dcte := pbu_$dctes[unit];
    if (dcte <> nil) and then (dcte^.owner <> 0) and then
       not dcte^.flags.kernel_driver then begin
      setdown_unit := unit;
      pbu_$setdown(setdown_unit, nil, status);
      if status.all <> status_$ok then
        exit;
    end;
  end;
end;
