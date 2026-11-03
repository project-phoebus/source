{ pbu_clear_iomap - clear the I/O map entries of freed map space.

  Image addresses:
    sau3  0x00E58EAE  pbu_clear_iomap (module-local)
    sau4  0x0F861ABE  pbu_clear_iomap (module-local)
    sau5  0x00E5907E  pbu_clear_iomap (module-local)

  - Only with the Multibus present: the IOMAP entries of npages pages
    from iova's page.  The bus is not read.
  - With the 64 KB Multibus map (`mbus_map_64k') the space's pages are
    the map's from 192, as IO_$ALLOC_MAP records them.

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
%if mbus_map_64k %then
    first := iova div 1024 + 192;
%else
    first := iova div 1024;
%endif
    last := npages + first - 1;
    for page := first to last do
%if long_iomap or word_iomap %then
      iomap[page] := 0;
%else
      iomap[page].entry := 0;
%endif
  end;
end;
