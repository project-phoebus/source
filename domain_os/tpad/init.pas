{ TPAD_$INIT - set up the locator at boot.

  Image addresses:
    sau2  0x00E33570  TPAD_$INIT

  - Unit 1 becomes the current unit.  Each display unit present gets its
    width and height less one as its maximum cursor limits and its
    scales, and its conversion factors (1024 for a scale of 0).
  - The cursor starts at (512, 400), the touchpad maximum at 1500, the
    device type tpad_$unknown.
  - The module's .DATA block is reached by its address (tpad/tpad.pas).

  Status stored: none.
}

{ TODO(pascal) 12 unaddressed frame bytes (stand-ins unused_4, _6 and _1c)

  No object the code shows explains them.  The stand-ins unused_4 and
  unused_6 hold the top 6, declared first; two other locals, a pointer
  and a word, would fill them exactly in that order, but the code uses
  neither: the records are reached with the lower bound folded into the
  displacements, which a pointer local would carry in its own value, and the
  bound is the call's result.  The stand-in unused_1c holds the bottom 4 (a
  longword below unit, the 2 bytes between them rounding).  A lead
  reads those as a slot for the
  `with' temporary (the temporary itself is the register copy of the stepped
  pointer); that reading is not established outside TPAD,
  so the stand-in stays until it is.  The frame-bytes survey in
  tty/k_flush_input.pas has the TPAD rows. }

{ TODO(pascal) the loop's guard forms a boolean and tests it

  The loop's guard forms the boolean n - 1 < 0 in the index's register
  and tests it, where the known loop guards branch on the flags of the
  decrement (DTTY_$WRITE_STRING); the only such form after
  a decrement in compiled code.  It is the overflow-correct test of n - 1 <
  0; whether a bound that is a function's result causes it is not known. }

[section(os_init_proc, os_init_data)]
procedure tpad_$init;
var
  unused_4: integer32;                    { stand-in, see TODO }
  unused_6: integer;                      { stand-in, see TODO }
  disp_info: smd_disp_info_result_t;
  status: status_$t;
  unit: integer;
  unused_1c: integer32;                   { stand-in, see TODO }
begin
  tpad_$set_unit(1);

  { each display unit }
  for unit := 1 to smd_$n_devices do
    with tpad_$unit_configs[unit] do begin
      smd_$inq_disp_info(unit, disp_info, status);

      { a display is present }
      if disp_info.display_type <> smd_$none then begin
        y_max_disp := disp_info.dims.height - 1;
        x_max_disp := disp_info.dims.width - 1;
      end;

      x_scale := x_max_disp;
      y_scale := y_max_disp;

      { the conversion factors }
      if x_scale = 0 then
        x_factor := 1024
      else
        x_factor := x_range div x_scale;
      if y_scale = 0 then
        y_factor := 1024
      else
        y_factor := y_range div y_scale;
    end;

  { the scalars }
  time_$clock(tpad_$last_clock);
  tpad_$cursor.line := 512;
  tpad_$cursor.column := 400;
  tpad_$button_state := 0;
  tpad_$accum_x := 0;
  tpad_$accum_y := 0;
  tpad_$touchpad_max := 1500;
  tpad_$dev_type := tpad_$unknown;
end;
