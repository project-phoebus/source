{ os_$start_proc2 - free the boot-only pages and start process 2.

  Image addresses:
    sau2  0x00E6D254  os_$start_proc2 (module-local)
    sau3  0x00E6D800  os_$start_proc2 (module-local)
    sau4  0x0F876D32  os_$start_proc2 (module-local)
    sau5  0x00E6E930  os_$start_proc2 (module-local)
    sau6  0x78075D9E  os_$start_proc2 (module-local)
    sau7  0x3C480716  os_$start_proc2 (module-local)
    sau8  0x03C765D2  os_$start_proc2

  - The pages from OS_INIT_START to OS_INIT_END, rounded up to a 32 KB
    segment, go back to the free pool.
  - FIM_$PROC2_STARTUP enters the new process and does not return.

  Status stored: none.
}

procedure os_$start_proc2(in ctx: fim_$startup_context_t); internal;
var
  top: integer32;
  va: integer32;
begin
  top := (integer32(addr(os_init_end)) + 16#7FFF) & (-16#8000);
  va := integer32(addr(os_init_start));

  while top > va do begin
    os_$free_va_page(va);
    va := va + 1024;
  end;

  acl_$clear_super;
  fim_$proc2_startup(ctx);
end;
