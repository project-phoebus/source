{ MMAP_$WIRE - wire a page.

  Image addresses:
    sau2  0x00E0CCBC  MMAP_$WIRE
    sau4  0x0F80D30C  MMAP_$WIRE
    sau6  0x7800D4A0  MMAP_$WIRE
    sau7  0x3C40E6F0  MMAP_$WIRE
    sau8  0x03C0DBDC  MMAP_$WIRE
    sau9  0x3C40EC18  MMAP_$WIRE

  - A wire count already at 57 crashes the system ("bad unavail");
    otherwise it goes up by one, and a page on a global pool (index
    below 5) is taken off it.

  Status stored: none.
}

procedure mmap_$wire(ppn: integer32);
begin
  with mmap[ppn]: page do begin
    if page.wire_count = 57 then
      crash_system(status_$mmap_bad_unavail);
    page.wire_count := page.wire_count + 1;
    if page.in_wsl and then (page.wsl_index < 5) then
      mmap_$remove_from_wsl(page, ppn);
  end;
end;
