{ IOMAP_$READ - read the AT bus's I/O map entry of a bus address.

  Image addresses:
    sau7  0x3C40C392  IOMAP_$READ

  - The result is the entry of iova's bus page, the memory page number
    it reaches (0 for none).  The bus number is not read.

  Status stored: none.
}

[section(wired_proc, wired_data)]
function iomap_$read(bus: integer; iova: integer32): integer32;
  options(val_param);
begin
  iomap_$read := iomap[rshft(iova, 10)];
end;
