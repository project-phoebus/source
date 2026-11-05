{ MONO_$DISPLAY_LOGO - copy the boot logo into display memory.

  Image addresses:
    sau7  0x3C4845B0  MONO_$DISPLAY_LOGO
    sau8  0x03C79E5C  MONO_$DISPLAY_LOGO

  - The display memory is mapped here for the copy and unmapped after
    it; nothing is copied or unmapped when the map fails.
  - The logo, 150 rows of 64 bytes, is centered by the vector's width
    and height, line by line at the display memory's line length.

  Status stored:
    status_$ok: stored first
    MST_$MAP's status: the memory could not be mapped
    MST_$UNMAP's status: the memory was mapped
}

procedure mono_$display_logo(dcte: mono_$dcte_ptr_t; logo: smd_logo_ptr_t;
                             out status: status_$t);
  options(val_param);
var
  info: mono_$info_ptr_t;
  hdm: mono_$hdm_ptr_t;
  map_info: integer32;
  size: integer32;
  va: integer32;
  bytes_per_line: integer;
  x: integer;
  y: integer;
  line: integer32;
  row: integer;
  col: integer;
begin
  status.all := status_$ok;
  info := dcte^.info;
  hdm := dcte^.hdm;
  bytes_per_line := hdm^.line_bits div 8;
  size := bytes_per_line * hdm^.word_74;
  x := hdm^.width div 16 - mono_$logo_words;
  y := hdm^.height div 2 - mono_$logo_rows div 2;
  va := integer32(mst_$map(info^.display_uid, 0, size, 6, 0, false,
                           map_info, status));
  line := x + bytes_per_line * y + va;
  if status.all = status_$ok then begin
    for row := 1 to mono_$logo_rows do begin
      for col := 1 to mono_$logo_words do
        mono_$line_ptr_t(line)^[col - 1] := logo^[row, col];
      line := line + bytes_per_line;
    end;
    mst_$unmap(info^.display_uid, va, size, status);
  end;
end;
