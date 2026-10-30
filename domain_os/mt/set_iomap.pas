{ mt_$set_iomap - map a physical page at an I/O address (nested in
  MT_$ACQUIRE).

  Image addresses:
    sau5  0x00E75CBA  mt_$set_iomap (nested)

  - On the SAUs whose I/O map entries are longwords (long_iomap,
    base/config.ins.pas) the entry is the page number plus
    mt_iomap_bias, the storage module drivers' form (sm/cinit.pas).
  - Nested in MT_$ACQUIRE after init_unit, where the image places it;
    it reads nothing of MT_$ACQUIRE's.

  Status stored: none.
}

  procedure mt_$set_iomap(ppn: integer32; iova: linteger); val_param;
  begin
%if long_iomap %then
    iomap[rshft(iova, 10)] := ppn + mt_iomap_bias;
%else
    { TODO(sau) the SAU3's and SAU4's entry

      Their MT code stores the entry as a word (the storage module
      drivers' other form, sm/cinit.pas); written when those SAUs are
      translated. }
%endif
  end;
