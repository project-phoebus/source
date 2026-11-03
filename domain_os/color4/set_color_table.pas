{ COLOR4_$SET_COLOR_TABLE - load entries of the color lookup table.

  Image addresses:
    sau8  0x03C798A0  COLOR4_$SET_COLOR_TABLE

  - count entries from first, through the board's registers
    (COLOR4_$LOAD_LUT).

  Status stored:
    COLOR4_$LOAD_LUT's status: always
}

procedure color4_$set_color_table(dcte: color4_$dcte_ptr_t;
                                  first: integer; count: integer;
                                  in colors: color4_$color_table_t;
                                  out status: status_$t);
  options(val_param);
var
  regs: color4_$regs_ptr_t;
begin
  regs := dcte^.info^.regs;
  color4_$load_lut(regs, first, count, colors, status);
end;
