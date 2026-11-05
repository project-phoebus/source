{ IOMAP_$UNMAP - unmap a run of the AT bus's pages.

  Image addresses:
    sau7  0x3C40C3B6  IOMAP_$UNMAP

  - count entries from iova's bus page are cleared.  The bus number is
    not read.

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes unexplained (stand-in unused_8)

  The frame is 8 bytes: page and i account for 4.  The image also loads
  the bus number at entry and overwrites it unread, the form of a
  value parameter some statement reads (as for a `for' loop's body); no
  statement of this body reads it.  The source that held the 4 bytes and
  read the bus number is not known; the stand-in unused_8 holds the
  bytes. }

[section(wired_proc, wired_data)]
procedure iomap_$unmap(bus: integer; iova: integer32; count: integer);
  options(val_param);
var
  page: integer;
  i: integer;
  unused_8: integer32;                    { stand-in: TODO above }
begin
  page := rshft(iova, 10);
  for i := 1 to count do
    iomap[i + page - 1] := 0;
end;
