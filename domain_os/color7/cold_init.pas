{ COLOR7_$COLD_INIT - forget the registers' owner at cold start.

  Image addresses:
    sau7  0x3C43FD6A  COLOR7_$COLD_INIT

  - No process or address space has the registers; the descriptor is not
    read.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure color7_$cold_init(dcte: color7_$dcte_ptr_t);
  options(val_param);
begin
  color7_static.owner := 0;
  color7_static.asid := 0;
end;
