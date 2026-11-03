{ SMD_$RETURN_DISPLAY - give a borrowed display unit back.

  Image addresses:
    sau2  0x00E6F700  SMD_$RETURN_DISPLAY
    sau4  0x0F879F50  SMD_$RETURN_DISPLAY
    sau5  0x00E71B28  SMD_$RETURN_DISPLAY
    sau9  0x3C475D38  SMD_$RETURN_DISPLAY

  - The unit becomes the caller's display unit again; the borrower is
    unmapped from it, and the display reset in full.
  - A screen manager that owns the unit gets a return request (member 14
    of the pending requests) and the overlay's ec_2 advanced.
  - When the caller is not the borrower, no status is written.
  - With `display_devices' (base/config.ins.pas) the unit's device gets
    the four cursor patterns and is dissociated from the borrower.

  Status stored:
    smd_$unmap_display_u's status: the caller is the borrower
      (smd_$not_mapped becomes status_$ok)
    the device's dissociation's status: with `display_devices'
    smd_$illegal_unit: the unit is not valid
    smd_$not_borrowed: the display is not borrowed
}

{ TODO(pascal) SMD_$RETURN_DISPLAY's frame: 12 of its 0x10 bytes not accounted

  The image's frame has 16 bytes and addresses no frame slot: the two
  records' addresses are held in registers.  dpc's layout
  (`--dump-locals' on the gate's copy) gives the routine as written 4
  bytes (a `with' slot); the other 12 are not accounted
  (BAT_$CANCEL's two `with' temporaries, a similar site, take 8
  bytes). }

procedure smd_$return_display(in unit: integer; out status: status_$t);
%if display_devices %then
var
  i: integer;
%endif
begin
  if not smd_$validate_unit(unit) then begin
    status.all := smd_$illegal_unit;
    return;
  end;
  with smd_$wired_data.unit[unit], hw^ do begin
    if not tracking_enabled then begin
      status.all := smd_$not_borrowed;
      return;
    end;
    asid_to_unit[proc1_$as_id] := unit;
    if borrowed_asid = proc1_$as_id then begin
      smd_$unmap_display_u(status);
      if status.all = smd_$not_mapped then
        status.all := status_$ok;
    end;
    discard(smd_$acq_display(0));
    field_1c := op_ec.value;
    smd_$reset_display_globals(unit, false);
    smd_$reset_unit_display(unit, true);
%if display_devices %then

    { the device gets the four cursors' patterns }
    crsr_versions := smd_$wired_data.crsr_versions;
    for i := 0 to 3 do
      with smd_$cursor_ptable[i]^ do
        vector^.load_crsr^(dcte, i, 16, hot_x, hot_y_adj, bitmap);
%endif
    smd_$rel_display;
%if display_devices %then
    vector^.dissoc^(dcte, status);
%endif
%if color_board %then
    if display_type in [smd_$color_display, smd_$800_color] then
      color_$dissoc;
%endif
%if gpu_driver %then
    if display_type in [smd_$color2_display, smd_$color3_display] then
      color2_$dissoc;
%endif
%if two_display_units %then
    { a process that borrowed the other unit too is that unit's again }
    if smd_$wired_data.unit[3 - unit].borrowed_asid = borrowed_asid then
      asid_to_unit[proc1_$as_id] := 3 - unit;
%endif
    borrowed_asid := 0;
    tracking_enabled := false;
    if owner_asid <> 0 then begin
      field_4c := field_4c + [14];
      ec_$advance(smd_$wired_data.ec_2);
    end;
  end;
end;
