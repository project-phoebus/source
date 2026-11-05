{ TPAD_$SET_UNIT_CURSOR - set the current unit and the cursor position.

  Image addresses:
    sau2  0x00E698C2  TPAD_$SET_UNIT_CURSOR
    sau4  0x0F873388  TPAD_$SET_UNIT_CURSOR
    sau6  0x780724E8  TPAD_$SET_UNIT_CURSOR
    sau7  0x3C47CE5C  TPAD_$SET_UNIT_CURSOR

  - unitp becomes the current unit and the cursor is put at new_crsr;
    in a mode other than absolute the cursor offset is re-taken from
    the raw position.
  - The check reads the current unit, tpad_$unit; the record is unitp's.

  Status stored:
    smd_$illegal_unit: the current unit is not 1 .. SMD_$N_DEVICES
    none: the cursor was set (the status is not written)
}

{ TODO(pascal) 4 frame bytes unaddressed (stand-in unused_4)

  The frame holds no object the code addresses: 4 bytes that nothing
  the image shows explains.  The stand-in unused_4 holds the place, as
  in the KBD and TTY routines (tty/k_flush_input.pas, the frame-bytes survey).
  A lead reads the
  bytes as a slot for the `with' statement's temporary; that reading is
  not established outside TPAD, so the
  stand-in stays until it is. }

procedure tpad_$set_unit_cursor(in unitp: integer; in new_crsr: smd_$pos_t;
                                out status_ret: status_$t);
var
  unused_4: integer32;                    { stand-in, see TODO }
begin
  { the current unit must exist }
  if (tpad_$unit <= 0) or (tpad_$unit > smd_$n_devices) then begin
    status_ret.all := smd_$illegal_unit;
    return;
  end;

  with tpad_$unit_configs[unitp] do begin
    tpad_$unit := unitp;
    tpad_$accum_x := 0;
    tpad_$accum_y := 0;
    tpad_$cursor := new_crsr;

    { re-origin a relative mode }
    if mode <> tpad_$absolute then begin
      cursor_offset.column := tpad_$cursor.column - tpad_$raw_x;
      cursor_offset.line := tpad_$cursor.line - tpad_$raw_y;
    end;
  end;
end;
