{ gpu_$unwire_buffers - unwire GPU_$DIAG_WIRE's pages.

  Image addresses:
    sau5  0x00E73CF6  gpu_$unwire_buffers (module-local)

  - The pages are unwired last first, and the count cleared.

  Status stored: none.
}

procedure gpu_$unwire_buffers; internal;
var
  i: integer;
begin
  for i := diag_wired downto 1 do
    wp_$unwire(wired_pages[i]);
  diag_wired := 0;
end;
