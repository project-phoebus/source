{ sm_$page_offset - an address's offset in its 1 KB page.

  Image addresses:
    sau3  0x00E6DB00  sm_$page_offset (module-local; the map's SM_$PROC_START)
    sau4  0x0F87727C  sm_$page_offset (module-local; the map's SM_$PROC_START)
    sau5  0x00E6EE58  sm_$page_offset (module-local; the map's SM_$PROC_START)

  - The controller is given a buffer as its offset in the page the I/O
    map maps.
  - The map's SM_$PROC_START, the mark of the module's wired range, is
    at its first byte; the routine has no name of its own.

  Status stored: none.
}

function sm_$page_offset(va: univ_ptr): integer32; internal;
begin
  sm_$page_offset := integer32(va) & 16#3FF;
end;
