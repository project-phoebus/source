{ MONO9_$DISPLAY_LOGO - copy the boot logo into display memory.

  Image addresses:
    sau9  0x3C476FFA  MONO9_$DISPLAY_LOGO

  - The display memory is mapped (MST_$MAP), the logo's 150 rows of 32
    words copied to the middle of the visible screen, and the memory
    unmapped (MST_$UNMAP).
  - The status is tested twice before the copy, the second time with
    nothing between that could change it.

  Status stored:
    MST_$MAP's status: the memory could not be mapped
    MST_$UNMAP's status: the logo was copied
}

procedure mono9_$display_logo(dcte: mono9_$dcte_ptr_t;
                              logo: smd_logo_ptr_t;
                              out status: status_$t);
  options(val_param);
var
  info: mono9_$info_ptr_t;
  hdm: mono9_$hdm_ptr_t;
  map_info: integer32;
  va: integer32;
  bytes_per_line: integer;
  x: integer;
  y: integer;
  line: integer32;
  row: integer;
  col: integer;
begin
  info := dcte^.info;
  hdm := dcte^.hdm;
  va := integer32(mst_$map(info^.display_uid, 0, mono9_$memory_size, 6, 0,
                           false, map_info, status));
  if status.all = status_$ok then begin
    { the logo's first line: centred, 64 bytes by 150 lines }
    bytes_per_line := hdm^.line_bits div 8;
    x := hdm^.width div 16 - 32;
    y := hdm^.height div 2 - 75;
    line := x + bytes_per_line * y + va;
    if status.all = status_$ok then begin
      for row := 1 to mono9_$logo_rows do begin
        for col := 1 to mono9_$logo_words do
          mono9_$logo_line_ptr_t(line)^[col] := logo^[row, col];
        line := line + bytes_per_line;
      end;
      mst_$unmap(info^.display_uid, va, mono9_$memory_size, status);
    end;
  end;
end;
