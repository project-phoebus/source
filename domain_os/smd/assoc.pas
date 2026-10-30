{ SMD_$ASSOC - associate a display unit with a process.

  Image addresses:
    sau2  0x00E6D882  SMD_$ASSOC
    sau5  0x00E6FB96  SMD_$ASSOC
    sau9  0x3C47451A  SMD_$ASSOC

  - The unit becomes the current one, line 0 gets the real line
    discipline, and TPAD is told the unit.
  - The unit goes to the current process, or to asid when there is none
    (PROC1_$AS_ID 0), with a full reset and no borrower.
  - With `two_display_units' (base/config.ins.pas) the new owner gives
    up the other unit; with `display_devices' the unit's device gets the
    four cursor patterns.

  Status stored:
    term_$set_real_line_discipline's status: the unit was associated
    smd_$illegal_unit: the unit has no display
}

{ TODO(pascal) frame of SMD_$ASSOC not accounted

  The image's frame is 12 bytes, and the code addresses no frame byte.
  no_display (2), owner (2) and the `with' slot of unit[unit] (4) give 8
  bytes; 4 are not explained.  A slot for the `with' of hw^ (a pointer's
  temporary) would make the 12; smd/reset_unit_display.pas has the same
  question.  dpc's layout gives 8. }

procedure smd_$assoc(in unit: integer; in asid: pinteger;
                     out status: status_$t);
var
  no_display: boolean;
  owner: proc1_$asid_t;
%if display_devices %then
  i: integer;
%endif
begin
  no_display := smd_$inq_disp_type(unit) = smd_$none;
  if no_display then
    status.all := smd_$illegal_unit
  else begin
    status.all := status_$ok;
    default_unit := unit;
    term_$set_real_line_discipline(0, term_$disc_disable_alt,
                                   status);
    tpad_$set_unit(unit);

    { the current process, or the caller's }
    owner := proc1_$as_id;
    if owner = 0 then
      owner := asid;

    with smd_$wired_data.unit[unit], hw^ do begin
%if display_devices %then
      smd_$reset_unit_display(unit, true);

      { the device gets the four cursors' patterns }
      crsr_versions := smd_$wired_data.crsr_versions;
      for i := 0 to 3 do
        with smd_$cursor_ptable[i]^ do
          vector^.load_crsr^(dcte, i, 16, hot_x, hot_y_adj, bitmap);
%else
      owner_asid := 0;
      smd_$reset_unit_display(unit, true);
%endif
      owner_asid := owner;
      borrowed_asid := 0;
      tracking_enabled := false;
      asid_to_unit[owner] := unit;
%if two_display_units %then
      { the process no longer owns the other unit }
      if smd_$wired_data.unit[3 - unit].owner_asid = owner then
        smd_$wired_data.unit[3 - unit].owner_asid := 0;
%endif
      smd_$reset_display_globals(unit, true);
    end;
  end;
end;
