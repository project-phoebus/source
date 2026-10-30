{ SMD_$DISPLAY_LOGO - copy the boot logo into display memory.

  Image addresses:
    sau2  0x00E701EE  SMD_$DISPLAY_LOGO
    sau5  0x00E7272E  SMD_$DISPLAY_LOGO
    sau9  0x3C476896  SMD_$DISPLAY_LOGO

  - The logo (150 rows of 32 words) goes to the first of units 1 and 2
    with a display, at row 438, word 16 of a 2048-pixel-wide display
    (types 5 and 9) or word 8 of a 1024-pixel-wide one.
  - Neither unit with a display: nothing is copied.
  - With `display_devices' (base/config.ins.pas) the unit's device
    draws the logo.

  Status stored:
    status_$ok: the logo was copied, or there was no display
    smd_$illegal_unit: unit is not valid
    the device's display_logo's status: with `display_devices'
}
{ TODO(pascal) SMD_$DISPLAY_LOGO's frame not accounted

  The image's frame is 0x14 bytes: disp_type at -0x4, the outer `for'
  count at -0xE and the strength-reduced row * 256 at -0x14; -0x2,
  -0xC..-0x6 and -0x12 are never addressed.  dpc's frame for the
  declared locals is 12 bytes; the image keeps logo_unit, row and col
  out of the frame and disp_type 2 bytes lower.  Where the compiler puts
  a spilled loop count and a spilled product is not known.  Not
  settled. }

procedure smd_$display_logo(in unit: integer;
                            in logo_data: smd_logo_ptr_t;
                            out status: status_$t);
var
  disp_type: smd_$display_type_t;
  logo_unit: integer;
  row: integer;                           { not materialized }
  col: integer;                           { not materialized }
begin
  if not smd_$validate_unit(unit) then begin
    status.all := smd_$illegal_unit;
    return;
  end;
%if display_devices %then
  with smd_$wired_data.unit[unit] do
    vector^.display_logo^(dcte, logo_data, status);
%else
  status.all := status_$ok;

  { the first unit with a display }
  disp_type := smd_$inq_disp_type(1);
  logo_unit := 1;
  if disp_type = smd_$none then begin
    disp_type := smd_$inq_disp_type(2);
    logo_unit := 2;
    if disp_type = smd_$none then
      return;
  end;

  { the copy, row by row }
  with smd_$wired_data.unit[logo_unit] do
    for row := 1 to 150 do
      for col := 1 to 32 do
        if disp_type in [smd_$color2_display, smd_$bw4_1280x1024] then
          smd_wide_memory_ptr_t(display_base)^[row + 437, col + 15] :=
            logo_data^[row, col]
        else
          display_base^[row + 437, col + 7] :=
            logo_data^[row, col];
%endif
end;
