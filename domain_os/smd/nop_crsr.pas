{ SMD_$NOP_CRSR - the default for a device's cursor pattern load: nothing.

  Image addresses:
    sau9  0x3C474374  SMD_$NOP_CRSR

  Status stored: none.
}

procedure smd_$nop_crsr(dcte: univ_ptr; cnum: integer; size: integer;
                        hot_x: integer; hot_y: integer;
                        in bitmap: smd_$cursor_bitmap_t);
  options(val_param);
begin
end;
