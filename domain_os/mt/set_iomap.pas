{ mt_$set_iomap - map a physical page at an I/O address (nested in
  MT_$ACQUIRE).

  Image addresses:
    sau3  0x00E70152  mt_$set_iomap (nested)
    sau5  0x00E75CBA  mt_$set_iomap (nested)

  - The entry is the page number plus mt_iomap_bias: a longword on the
    SAUs with long_iomap (base/config.ins.pas), elsewhere the first
    word of the entry's 4 bytes, the storage module drivers' forms
    (sm/cinit.pas).
  - Nested in MT_$ACQUIRE after init_unit, where the image places it;
    it reads nothing of MT_$ACQUIRE's.

  Status stored: none.
}

{ TODO(sau) the SAU4's I/O map entries

  The SAU4's I/O map is a word an entry, at its own address, and its
  mt_$set_iomap and MT_$SIO store the page number alone (as its
  storage module drivers do, the TODO(sau) in sm/cinit.pas).  Neither
  arm below is its form. }

  procedure mt_$set_iomap(ppn: integer32; iova: linteger); val_param;
  begin
%if long_iomap %then
    iomap[rshft(iova, 10)] := ppn + mt_iomap_bias;
%else
    iomap[rshft(iova, 10)].entry := ppn + mt_iomap_bias;
%endif
  end;
