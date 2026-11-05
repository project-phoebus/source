{ color6_get_page - the page-select value the board is at.

  Image addresses:
    sau7  0x3C48C938  color6_get_page (module-local)

  - From the configuration register's bits 4 and 5: page 6 for none,
    page 3 for bit 5 alone, page 5 otherwise, each with the select
    register's high bits.

  Status stored: none.
}

[section(color6_wired_proc, wired_data)]
function color6_get_page(regs: color6_$regs_ptr_t): color6_$byte_t;
begin
  case color6_swap16(regs^.page_cfg) & 16#30 of
    0:     color6_get_page := 16#FE;
    16#20: color6_get_page := 16#FB;
    otherwise
      color6_get_page := 16#FD;
  end;
end;
