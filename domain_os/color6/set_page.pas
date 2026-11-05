{ color6_set_page - select a page of the board.

  Image addresses:
    sau7  0x3C48C96E  color6_set_page (module-local)

  - The select register cleared, then the page with the register's high
    bits.

  Status stored: none.
}

[section(color6_wired_proc, wired_data)]
procedure color6_set_page(regs: color6_$regs_ptr_t; page: color6_$byte_t);
begin
  regs^.page_sel := 0;
  regs^.page_sel := page ! color6_$page_sel_bits;
end;
