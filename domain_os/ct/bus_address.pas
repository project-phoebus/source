{ ct_bus_address - the bus address of a buffer in an I/O map region.

  Image addresses:
    sau7  0x3C485B96  ct_bus_address (module-local)

  - The buffer's offset in its 1 KB page added to the region's bus
    address, where the region maps the buffer's page first.
  - The frame holds bytes the code does not touch (unused, a stand-in).

  Returns:
    the bus address

  Status stored: none.
}

function ct_bus_address(va: integer32; base: integer32): integer32;
  internal;
var
  unused: array[1..3] of integer;
begin
  ct_bus_address := (va & 16#3FF) + base;
end;
