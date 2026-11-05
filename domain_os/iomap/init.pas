{ IOMAP_$INIT - clear the AT bus's I/O map.

  Image addresses:
    sau7  0x3C4379F0  IOMAP_$INIT

  - All 1024 entries, from bus address 0.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure iomap_$init;
begin
  iomap_$unmap(1, 0, 1024);
end;
