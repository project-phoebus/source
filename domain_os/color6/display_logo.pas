{ COLOR6_$DISPLAY_LOGO - copy the boot logo into display memory.

  Image addresses:
    sau7  0x3C483B98  COLOR6_$DISPLAY_LOGO

  - At the unit's page, the display memory mapped (MST_$MAP); once the
    board is idle the visible screen is cleared and the logo copied to
    its middle, then the memory unmapped.

  Status stored:
    MST_$MAP's status: the memory could not be mapped
    COLOR6_$BUSY_WAIT's status, then MST_$UNMAP's
}

procedure color6_$display_logo(dcte: color6_$dcte_ptr_t;
                               logo: smd_logo_ptr_t;
                               out status: status_$t);
  options(val_param);
var
  info: color6_$info_ptr_t;
  hdm: color6_$hdm_ptr_t;
  saved: color6_$byte_t;
  map_info: integer32;
  va: integer32;
  row_bytes: pinteger;
  x: pinteger;
  y: pinteger;
  p: color6_$row_ptr_t;
  row: integer;
  col: integer;
  st: status_$t;
begin
  info := dcte^.info;
  hdm := dcte^.hdm;
  saved := color6_get_page(info^.regs);
  color6_set_page(info^.regs, dcte^.cnum);
  va := integer32(mst_$map(color6_display_uid, 0, color6_$memory_size, 6,
                           0, false, map_info, status));
  if status.all = status_$ok then begin
    row_bytes := hdm^.line_bits div 8;
    x := hdm^.width div 16 - color6_$logo_words;
    y := hdm^.height div 2 - color6_$logo_rows div 2;
    p := color6_$row_ptr_t(va);
    color6_$busy_wait(dcte, status);
    for row := 1 to hdm^.height do begin
      for col := 1 to hdm^.width div 16 do
        p^[col] := 0;
      p := color6_$row_ptr_t(integer32(p) + row_bytes);
    end;
    p := color6_$row_ptr_t(x + row_bytes * y + va);
    for row := 1 to color6_$logo_rows do begin
      for col := 1 to color6_$logo_words do
        p^[col] := logo^[row, col];
      p := color6_$row_ptr_t(integer32(p) + row_bytes);
    end;
    mst_$unmap(color6_display_uid, va, color6_$memory_size, st);
    status := st;
  end;
  color6_set_page(info^.regs, saved);
end;
