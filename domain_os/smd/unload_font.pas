{ SMD_$UNLOAD_FONT - unload a font from hidden display memory.

  Image addresses:
    sau2  0x00E6DD18  SMD_$UNLOAD_FONT
    sau4  0x0F878436  SMD_$UNLOAD_FONT
    sau5  0x00E7011A  SMD_$UNLOAD_FONT
    sau6  0x780774BA  SMD_$UNLOAD_FONT

  - The font's hidden display memory goes back to the free list (its
    size by the font's version), and the slot is cleared.

  Status stored:
    smd_$free_hdm's status: the font was unloaded
    smd_$illegal_caller: the process has no display unit
    smd_$font_not_loaded: the slot is outside 1..8, or empty
}

procedure smd_$unload_font(in font_id: pinteger; out status: status_$t);
var
  unit: integer;
  font: smd_$font_table_ptr_t;
begin
  unit := asid_to_unit[proc1_$as_id];
  if unit = 0 then
    status.all := smd_$illegal_caller
  else if (font_id = 0) or (font_id > 8) then
    status.all := smd_$font_not_loaded
  else
    with smd_$wired_data.unit[unit].font_table^[font_id] do
      if font_va = nil then
        status.all := smd_$font_not_loaded
      else begin
        font := font_va;
        if font^.version = 3 then
          smd_$free_hdm(smd_font_v3_ptr_t(font)^.hdm_size, hdm_pos,
                        status)
        else
          smd_$free_hdm(font^.raster_lines, hdm_pos, status);
        font_va := nil;
      end;
end;
