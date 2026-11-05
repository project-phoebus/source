{ IOMAP_$MAP - map a run of the AT bus's pages to memory pages.

  Image addresses:
    sau7  0x3C40C340  IOMAP_$MAP

  - The run starts at the bus page of iova; its entry i gets the low
    word of ppns[i], i from 1 to count.  The bus number, vas and flags
    are not read.

  Status stored:
    status_$ok: always
}

{ TODO(pascal) 4 frame bytes unexplained (stand-in unused_8)

  The frame is 8 bytes: page and i account for 4.  The image also loads
  the bus number at entry and overwrites it unread, the form of a
  value parameter some statement reads (as for a `for' loop's body); no
  statement of this body reads it.  The source that held the 4 bytes and
  read the bus number is not known; the stand-in unused_8 holds the
  bytes. }

[section(wired_proc, wired_data)]
procedure iomap_$map(bus: integer; iova: integer32;
                     in ppns: univ iomap_$ppn_list_t;
                     in vas: univ iomap_$ppn_list_t;
                     count: integer; flags: integer;
                     out status: status_$t);
  options(val_param);
var
  page: integer;
  i: integer;
  unused_8: integer32;                    { stand-in: TODO above }
begin
  page := rshft(iova, 10);
  for i := 1 to count do
    iomap[i + page - 1] := ppns[i];
  status.all := status_$ok;
end;
