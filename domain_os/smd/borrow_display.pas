{ SMD_$BORROW_DISPLAY - lend a display unit to the calling process.

  Image addresses:
    sau2  0x00E6F584  SMD_$BORROW_DISPLAY
    sau4  0x0F879DD0  SMD_$BORROW_DISPLAY
    sau5  0x00E719A8  SMD_$BORROW_DISPLAY
    sau6  0x78078CF2  SMD_$BORROW_DISPLAY
    sau7  0x3C4824D6  SMD_$BORROW_DISPLAY
    sau9  0x3C475BF6  SMD_$BORROW_DISPLAY

  - Under the SMD respond lock, a screen manager that owns the unit is
    asked (a borrow request, member 15) and its answer waited for
    (SMD_$SEND_RESPONSE).
  - Granted, the caller becomes the borrower and the unit its display
    unit, and the display is put in its initial state.
  - full also clears a monochrome display to its limits (a failure
    crashes the system); without it the keyboard cursor is cleared.
    With `display_devices' (base/config.ins.pas) the display is not
    cleared.

  Status stored:
    status_$ok: the display was lent
    smd_$illegal_unit: the unit is not valid, or has no display
    smd_$already_borrowed: the unit is borrowed already
    smd_$access_denied: the screen manager refused
    smd_$init_display_state's status: the display's reset failed
}

{ TODO(pascal) SMD_$BORROW_DISPLAY's frame: 4 of its 0xC bytes not accounted

  The image's frame is 12 bytes, and the code addresses one slot,
  target at -0x4 (stored and never read back).  dpc's layout gives the
  routine as written 8 bytes (target at -4 and a `with' slot); the other
  4 (a second `with' slot for the two records?) are not accounted. }

procedure smd_$borrow_display(in unit: integer;
                              in full: boolean;
                              out status: status_$t);
var
  target: integer32;                      { also held in a register }
begin
  if not smd_$validate_unit(unit) or else
     (smd_$inq_disp_type(unit) = smd_$none) then begin
    status.all := smd_$illegal_unit;
    return;
  end;
  with smd_$wired_data.unit[unit], hw^ do begin
    ml_$lock(ml_$smd_respond_lock);
    if borrowed_asid <> 0 then begin
      ml_$unlock(ml_$smd_respond_lock);
      status.all := smd_$already_borrowed;
      return;
    end;
    if owner_asid <> 0 then begin
      target := cursor_ec.value + 1;
      field_4c := field_4c + [15];
      ec_$advance(smd_$wired_data.ec_2);
      discard(ec_$wait(addr(cursor_ec), addr(ec_$nil_ec),
                       addr(ec_$nil_ec), target, 0, 0));
      if not smd_response_val[unit] then begin
        status.all := smd_$access_denied;
        ml_$unlock(ml_$smd_respond_lock);
        return;
      end;
    end;
    borrowed_asid := proc1_$as_id;
    ml_$unlock(ml_$smd_respond_lock);
    asid_to_unit[proc1_$as_id] := unit;
    tracking_enabled := true;
    smd_$init_display_state(full, status);
    if status.all <> status_$ok then
      return;
    if not full then
      smd_$clear_kbd_cursor(status);
    smd_$reset_display_globals(unit, false);
%if not display_devices %then
    if full then
      if display_type in [smd_$bw_15p, smd_$bw_19l, smd_$bw_14l,
                          smd_$bw4_1280x1024,
                          smd_$bw5_1024x800] then begin
        smd_$clear_window(disp_limits, status);
        if status.all <> status_$ok then
          crash_system(smd_$borrow_error);
      end;
%endif
  end;
  status.all := status_$ok;
end;
