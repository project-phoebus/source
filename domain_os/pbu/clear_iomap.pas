{ pbu_clear_iomap - clear the I/O map entries of freed map space.

  Image addresses:
    sau5  0x00E5907E  pbu_clear_iomap (module-local)

  - Only with the Multibus present: the IOMAP entries of npages pages
    from iova's page.  The bus is not read.

  Status stored: none.
}

procedure pbu_clear_iomap(bus: integer; iova: linteger; npages: integer32);
  internal;
var
  first: pinteger;
  last: pinteger;
  page: pinteger;
begin
  if pbu_$mcb.present then begin
    first := iova div 1024;
    last := npages + first - 1;
    for page := first to last do
      iomap[page] := 0;
  end;
end;
