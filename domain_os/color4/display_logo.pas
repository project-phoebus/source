{ COLOR4_$DISPLAY_LOGO - copy the boot logo into display memory.

  Image addresses:
    sau7  0x3C483F16  COLOR4_$DISPLAY_LOGO
    sau8  0x03C797C2  COLOR4_$DISPLAY_LOGO

  - The display memory is mapped here for the copy and unmapped after
    it, whether or not the map succeeded.
  - The logo, 150 rows of 32 words, is centered by the vector's width
    and height.

  Status stored:
    status_$ok: stored first
    MST_$MAP's status: the memory could not be mapped
    MST_$UNMAP's status: last
}

procedure color4_$display_logo(dcte: color4_$dcte_ptr_t;
                               logo: smd_logo_ptr_t;
                               out status: status_$t);
  options(val_param);
var
  info: color4_$info_ptr_t;
  hdm: color4_$hdm_ptr_t;
  map_info: integer32;
  va: integer32;
  x: integer;
  y: integer;
  row: integer;
  col: integer;
begin
  status.all := status_$ok;
  info := dcte^.info;
  hdm := dcte^.hdm;
  x := hdm^.width div 32 - color4_$logo_words div 2;
  y := hdm^.height div 2 - color4_$logo_rows div 2;
  va := integer32(mst_$map(info^.display_uid, 0, color4_$memory_size, 6,
                           0, false, map_info, status));
  if status.all = status_$ok then
    for row := 1 to color4_$logo_rows do
      for col := 0 to color4_$logo_words - 1 do
        color4_$memory_ptr_t(va)^[y + row, x + col] := logo^[row, col + 1];
  mst_$unmap(info^.display_uid, va, color4_$memory_size, status);
end;
