{ COLOR6_$PUTC - write characters to the display TTY.

  Image addresses:
    sau7  0x3C48CD3C  COLOR6_$PUTC

  - count characters, one at a time (DTTY_$PUTC), at the unit's page.

  Status stored: none.
}

[section(color6_wired_proc, wired_data)]
procedure color6_$putc(dcte: color6_$dcte_ptr_t; in chars: color6_$chars_t;
                       count: integer);
  options(val_param);
var
  info: color6_$info_ptr_t;
  saved: color6_$byte_t;
  i: integer;
begin
  info := dcte^.info;
  saved := color6_get_page(info^.regs);
  color6_set_page(info^.regs, dcte^.cnum);
  for i := 1 to count do
    dtty_$putc(chars[i]);
  color6_set_page(info^.regs, saved);
end;
