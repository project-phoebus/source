{ MMAP_$UNWIRE - unwire a page.

  Image addresses:
    sau2  0x00E0CD1C  MMAP_$UNWIRE
    sau9  0x3C40EC78  MMAP_$UNWIRE

  - A wire count of 0 crashes the system ("bad avail"); otherwise it
    goes down by one, and a page then unwired and on no list goes on the
    current address space's list, at its tail.

  Status stored: none.
}

procedure mmap_$unwire(ppn: integer32);
begin
  with mmap[ppn]: page do begin
    if page.wire_count = 0 then
      crash_system(status_$mmap_bad_avail);
    page.wire_count := page.wire_count - 1;
    if (page.wire_count = 0) and then not page.in_wsl then
      mmap_$add_to_wsl(page, ppn, mmap_$ws_owner[proc1_$current], true);
  end;
end;
