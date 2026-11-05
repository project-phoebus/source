{ SMD_$INVERT_S - invert the current process's display.

  Image addresses:
    sau2  0x00E6DDA6  SMD_$INVERT_S
    sau4  0x0F8784CA  SMD_$INVERT_S
    sau5  0x00E701AE  SMD_$INVERT_S
    sau6  0x7807754C  SMD_$INVERT_S

  - The display is acquired while SMD_$INVERT_DISP inverts the unit's
    display memory.

  Status stored:
    status_$ok: the display was inverted
    smd_$illegal_caller: the process has no display unit
    smd_$not_on_color: with `color_displays' (base/config.ins.pas), a
      color display (types 3..6)
}

{ TODO(pascal) the early display-record address and 4 frame bytes of SMD_$INVERT_S

  The frame is 8 bytes: the one local, unit (2 bytes, held in a
  register), explains 4 of them.  A `with' slot of 4 bytes would explain
  the rest and the address formed before the status store (above), but
  no `with' fits: the routine reads no field of the display record, and
  a `with' gives no name for its whole record.  Whether the compiler
  hoists the address of a static array element passed by address, and
  gives it a frame slot, is not known.  A lead: the SAU5's code
  (`color_displays') forms the same address at the same place and reads
  the record's display_type through it for its color test, the first
  use; its frame is 8 bytes too. }

procedure smd_$invert_s(out status: status_$t);
var
  unit: integer;
begin
  status.all := smd_$illegal_caller;
  unit := asid_to_unit[proc1_$as_id];
  if unit <> 0 then
%if color_displays %then
    if smd_$display_com[unit].display_type in
       [smd_$color_display..smd_$color3_display] then
      status.all := smd_$not_on_color
    else
%endif
    begin
    status.all := status_$ok;
    discard(smd_$acq_display(0));
    smd_$invert_disp(smd_$wired_data.unit[unit].display_base,
                     smd_$display_com[unit]);
    smd_$rel_display;
  end;
end;
