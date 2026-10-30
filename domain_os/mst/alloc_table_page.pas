{ mst_$alloc_table_page - back an MST word with a fresh page of MSTEs.

  Image addresses:
    sau2  0x00E43F40  mst_$alloc_table_page (module-local)
    sau9  0x3C44B3F6  mst_$alloc_table_page (module-local)

  - For an ASID other than 0 and an MST word still 0, the first free
    page of the bitmap from the hint up is marked used and its number
    stored in the MST word.
  - The page is installed and cleared (mst_$init_table_page) and
    counted wired.
  - With the large address space, for any MST word, an inactive region
    of the segment is made active (its segment map page installed and
    put in RARS, the event logged).
  - Then the segment's BST page is installed if the ASID lacks it.

  Returns:
    status_$ok: a page was installed, or none was needed
    status_$virtual_memory_resources_exhausted: the bitmap is exhausted

  Status stored: none.
}

function mst_$alloc_table_page;
var
  word_index: pinteger;
  bit_pos: 0..31;
  unused_10: integer32;                   { stand-in }
  unused_14: integer32;
%if large_address_space %then
  group: pinteger;
  region: mst_region_t;
  page: 0..127;
%endif
begin
%if large_address_space %then
  if asid <> 0 then begin
    if entry = 0 then begin
%else
  if (asid <> 0) and then (entry = 0) then begin
%endif
    word_index := page_alloc_hint;
    while page_avail_bitmap[word_index] = [] do
      if word_index < mst_bitmap_last + 1 then
        word_index := word_index + 1
      else begin
        mst_$alloc_table_page := status_$t(integer32(
          status_$virtual_memory_resources_exhausted));
        return;
      end;
    page_alloc_hint := word_index;
    bit_pos := 0;
    while not (bit_pos in page_avail_bitmap[word_index]) do
      bit_pos := bit_pos + 1;
    page_avail_bitmap[word_index] :=
      page_avail_bitmap[word_index] - [bit_pos];
    word_index := word_index * 32 + bit_pos;
    entry := word_index;
    discard(mst_$init_table_page(
      linteger(addr(mste_pages[word_index]))));
    mst_$mst_pages_wired := mst_$mst_pages_wired + 1;
%if large_address_space %then
    end;
    group := seg div mst_region_segs;
    if group >= mst_private_a_regions then
      region := group + mst_global_a_regions
    else
      region := group;
    if not (region in mst_$regions_active[asid]) then begin
      mst_$set(mst_$regions_active[asid], 256, region);
      rars[rars_asid_base[asid] + region].all :=
        mst_$init_table_page(linteger(addr(
          smaps[lshft(group, 7) + smap_asid_base[asid]]))) * 1024 +
        mst_rars_valid;
      if netlog_$ok_to_log then
        netlog_$log_it(mst_region_netlog_kind, uid_$nil, 0, 0, 1, region,
                       0, 0);
    end;
    page := seg div 256;
    if not (page in mst_$bst_pages[asid]) then begin
      discard(mst_$init_table_page(linteger(
        addr(bst[lshft(page, 8) + bst_asid_base[asid]]))));
      mst_$bst_pages[asid] := mst_$bst_pages[asid] + [page];
    end;
%endif
  end;
  mst_$alloc_table_page := status_$t(integer32(status_$ok));
end;
