{ COLOR_$COLD_INIT - initialize the color board's driver at boot.

  Image addresses:
    sau5  0x00E372BC  COLOR_$COLD_INIT

  - The board's interrupt registers and control store page (16#3A, the
    global address space) are set up only when its status word answers
    TESTPAGE.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure color_$cold_init;
var
  location: univ_ptr;
  probe_data: integer;
begin
  color_owner := 0;
  color_page_count := 0;
  color_associated := false;
  ec_$init(color_$iq_done_ec);
  color_$vector_init;
  location := addr(color_sup.status);
  if testpage(1, location, probe_data) then begin
    color_$int_init;
    mmu_$install(16#3A, addr(color_cstore), 0, 6);
  end;
end;
