{ COLOR5_$DISPLAY_LOGO - copy the boot logo into display memory.

  Image addresses:
    sau8  0x03C79AFE  COLOR5_$DISPLAY_LOGO

  - The display memory, its line length times its lines, is mapped here
    for the copy and unmapped after it, whether or not the map
    succeeded.
  - The logo, 150 rows of 32 words, is centered by the vector's width
    and height.

  Status stored:
    status_$ok: stored first
    MST_$MAP's status: the memory could not be mapped
    MST_$UNMAP's status: the memory was mapped
}

procedure color5_$display_logo(dcte: color5_$dcte_ptr_t;
                               logo: smd_logo_ptr_t;
                               out status: status_$t);
  options(val_param);
var
  unmap_status: status_$t;
  hdm: color5_$hdm_ptr_t;
  y: integer;
  map_info: integer32;
  size: integer32;
  va: integer32;
  x: integer;
  info: color5_$info_ptr_t;
  row: integer;
  col: integer;
begin
  status.all := status_$ok;
  info := dcte^.info;
  hdm := dcte^.hdm;
  size := (hdm^.line_bits div 8) * hdm^.word_74;
  va := integer32(mst_$map(info^.display_uid, 0, size, 6, 0, false,
                           map_info, status));
  y := (hdm^.height - color5_$logo_rows) div 2;
  x := (hdm^.width div 16 - color5_$logo_words) div 2;
  if status.all = status_$ok then
    for row := 1 to color5_$logo_rows do
      for col := 0 to color5_$logo_words - 1 do
        color5_$memory_ptr_t(va)^[y + row, x + col] := logo^[row, col + 1];
  mst_$unmap(info^.display_uid, va, size, unmap_status);
  if status.all = status_$ok then
    status := unmap_status;
end;
