{ COLOR6_$SET_CRS_PAT - load a cursor's pattern into the board.

  Image addresses:
    sau7  0x3C4838DA  COLOR6_$SET_CRS_PAT

  - At the unit's page; when the control word's bit 12 is set the hot
    spot's y is counted from the pattern's bottom (its height in
    SMD_$CURSOR_TABLE).
  - A 16 by 16 cursor, the bitmap as both image and mask; size is not
    read; the command's status is dropped.

  Status stored: none.
}

procedure color6_$set_crs_pat(dcte: color6_$dcte_ptr_t; cnum: integer;
                              size: integer; hot_x: integer;
                              hot_y: integer;
                              bitmap: color6_$bitmap_ptr_t);
  options(val_param);
var
  info: color6_$info_ptr_t;
  saved: color6_$byte_t;
  y: integer;
  status: status_$t;
begin
  info := dcte^.info;
  saved := color6_get_page(info^.regs);
  color6_set_page(info^.regs, dcte^.cnum);
  if 12 in info^.regs^.ctl then
    hot_y := smd_$cursor_table[cnum].height - hot_y - 1;
  y := hot_y;
  color6_send_cursor(dcte, cnum, 16, 16, 1, 3, hot_x, y, bitmap, bitmap,
                     status);
  color6_set_page(info^.regs, saved);
end;
