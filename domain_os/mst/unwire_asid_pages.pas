{ mst_$unwire_asid_pages - free the pages of MSTEs behind a range of MST
  words.

  Image addresses:
    sau2  0x00E74AB6  mst_$unwire_asid_pages (module-local)
    sau8  0x03C7F368  mst_$unwire_asid_pages (module-local)
    sau9  0x3C47C424  mst_$unwire_asid_pages (module-local)

  Assume we're called with the ASID lock held.

  - Each nonzero MST word from start_word to end_word has its page of
    MSTEs given back and marked free in the bitmap, and is cleared; the
    allocation hint and MST_$MST_PAGES_WIRED follow.

  Status stored: none.
}

[section(proc2_delete_pro, data$)]
procedure mst_$unwire_asid_pages(start_word: integer; end_word: integer);
  internal;
var
  i: integer;
  word: pinteger;
  bit: pinteger;
  unused_c: integer;                      { stand-in }
begin
  for i := start_word to end_word do
    if mst[i] <> 0 then begin
      mst_$unwire_page(addr(mste_pages[mst[i]]));
      word := mst[i] div 32;
      bit := mst[i] & 31;
      page_avail_bitmap[word] := page_avail_bitmap[word] + [bit];
      mst[i] := 0;
      if word < page_alloc_hint then
        page_alloc_hint := word;
      mst_$mst_pages_wired := mst_$mst_pages_wired - 1;
    end;
end;
