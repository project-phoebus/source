{ mt_$set_iomap - map a physical page at an I/O address (nested in
  MT_$ACQUIRE).

  Image addresses:
    sau3  0x00E70152  mt_$set_iomap (nested)
    sau4  0x0F87CECA  mt_$set_iomap (nested)
    sau5  0x00E75CBA  mt_$set_iomap (nested)
    sau6  0x7807C976  mt_$set_iomap (nested)

  - The entry is the page number plus mt_iomap_bias: a longword on the
    SAUs with long_iomap (base/config.ins.pas), elsewhere the first
    word of the entry's 4 bytes, the storage module drivers' forms
    (sm/cinit.pas); with word entries (`word_iomap') the page number
    alone, at the map's entry 192 on for the 64 KB Multibus map
    (`mbus_map_64k').
  - Nested in MT_$ACQUIRE after init_unit, where the image places it;
    it reads nothing of MT_$ACQUIRE's.

  Status stored: none.
}

  procedure mt_$set_iomap(ppn: integer32; iova: linteger); val_param;
  begin
%if long_iomap %then
    iomap[rshft(iova, 10)] := ppn + mt_iomap_bias;
%elseif word_iomap %then
    iomap[rshft(iova, 10) + 192] := ppn;
%else
    iomap[rshft(iova, 10)].entry := ppn + mt_iomap_bias;
%endif
  end;
