{ COLOR7_$LOAD_CRSR - take a new cursor pattern.

  Image addresses:
    sau7  0x3C484986  COLOR7_$LOAD_CRSR

  - When the board has cnum's pattern, it is forgotten, so that the next
    COLOR7_$XOR_CURSOR loads it again; the pattern itself is not read
    here.

  Status stored: none.
}

procedure color7_$load_crsr(dcte: color7_$dcte_ptr_t; cnum: integer;
                            size: integer; hot_x: integer; hot_y: integer;
                            in bitmap: color7_$bitmap_t);
  options(val_param);
begin
  if cnum = color7_static.cursor then
    color7_static.cursor := -1;
end;
