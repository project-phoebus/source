{ pbu_clear_iomap - clear the I/O map entries of freed map space.

  Image addresses:
    sau3  0x00E58EAE  pbu_clear_iomap (module-local)
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
%if long_iomap %then
      iomap[page] := 0;
%else
      iomap[page].entry := 0;
%endif
  end;
end;
